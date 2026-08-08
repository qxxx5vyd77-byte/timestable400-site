"""Thin wrapper over tweepy for the handful of calls we actually make.

Design notes:
  * Posting and reading use the v2 API (tweepy.Client, OAuth 1.0a user context).
  * Media upload still goes through the v1.1 endpoint (tweepy.API) -- that is
    the only supported path for attaching media, and it is available on the
    Free and Basic tiers.
  * dry_run short-circuits every write so you can exercise the whole flow
    without spending quota or posting anything real.
"""

from __future__ import annotations

import logging
import mimetypes
from dataclasses import dataclass
from pathlib import Path

import tweepy

from .config import Config

logger = logging.getLogger("x_poster.client")

# X hard limit for a single post (standard). Premium longer-post limits are not
# assumed here -- the API still rejects >280 for most apps, so we guard on it.
MAX_TWEET_LEN = 280


@dataclass
class PostResult:
    tweet_id: str | None
    text: str
    dry_run: bool

    @property
    def url(self) -> str | None:
        if not self.tweet_id:
            return None
        return f"https://x.com/i/web/status/{self.tweet_id}"


class XClient:
    def __init__(self, config: Config):
        self._config = config
        # v2 client for posting + reading.
        self._client = tweepy.Client(
            consumer_key=config.api_key,
            consumer_secret=config.api_secret,
            access_token=config.access_token,
            access_token_secret=config.access_token_secret,
        )
        # v1.1 API only for media upload.
        self._auth = tweepy.OAuth1UserHandler(
            config.api_key,
            config.api_secret,
            config.access_token,
            config.access_token_secret,
        )
        self._api = tweepy.API(self._auth)
        self._me_id: str | None = None
        self._me_username: str | None = None

    # ------------------------------------------------------------------ auth
    def whoami(self) -> tuple[str, str]:
        """Return (user_id, username) for the authenticated account.

        Doubles as a credential smoke test -- if this succeeds, auth works.
        """
        if self._me_id and self._me_username:
            return self._me_id, self._me_username
        me = self._client.get_me()
        self._me_id = str(me.data.id)
        self._me_username = me.data.username
        return self._me_id, self._me_username

    # --------------------------------------------------------------- posting
    def upload_media(self, paths: list[Path]) -> list[str]:
        """Upload media files, returning their media_ids. No-op in dry-run."""
        media_ids: list[str] = []
        for p in paths:
            if not p.exists():
                raise FileNotFoundError(f"media file not found: {p}")
            if self._config.dry_run:
                logger.info("[dry-run] would upload media: %s", p)
                media_ids.append(f"dryrun-media-{p.name}")
                continue
            mime, _ = mimetypes.guess_type(str(p))
            chunked = bool(mime and mime.startswith("video"))
            logger.info("uploading media: %s (chunked=%s)", p, chunked)
            media = self._api.media_upload(filename=str(p), chunked=chunked)
            media_ids.append(str(media.media_id))
        return media_ids

    def post(
        self,
        text: str,
        *,
        media_paths: list[Path] | None = None,
        in_reply_to: str | None = None,
    ) -> PostResult:
        """Post a single tweet, optionally with media and/or as a reply."""
        if len(text) > MAX_TWEET_LEN:
            raise ValueError(
                f"text is {len(text)} chars, over the {MAX_TWEET_LEN} limit. "
                "Use post_thread() to split it."
            )

        media_ids = self.upload_media(media_paths) if media_paths else None

        if self._config.dry_run:
            logger.info(
                "[dry-run] would post: %r (reply_to=%s, media=%s)",
                text,
                in_reply_to,
                media_ids,
            )
            return PostResult(tweet_id=None, text=text, dry_run=True)

        resp = self._client.create_tweet(
            text=text,
            media_ids=media_ids,
            in_reply_to_tweet_id=in_reply_to,
        )
        tweet_id = str(resp.data["id"])
        logger.info("posted tweet %s", tweet_id)
        return PostResult(tweet_id=tweet_id, text=text, dry_run=False)

    def post_thread(
        self,
        parts: list[str],
        *,
        media_paths_first: list[Path] | None = None,
    ) -> list[PostResult]:
        """Post a chain of tweets, each replying to the previous one.

        Media (if given) attaches to the first tweet only.
        """
        results: list[PostResult] = []
        reply_to: str | None = None
        for i, part in enumerate(parts):
            result = self.post(
                part,
                media_paths=media_paths_first if i == 0 else None,
                in_reply_to=reply_to,
            )
            results.append(result)
            # In dry-run there is no id to chain from; keep going anyway.
            reply_to = result.tweet_id
        return results

    # -------------------------------------------------------------- mentions
    def get_mentions(self, *, since_id: str | None = None, max_results: int = 25):
        """Fetch recent mentions of the authenticated user.

        Returns the raw tweepy response. Reading mentions consumes read quota,
        which is why this is the capability that needs the paid Basic tier.
        """
        user_id, _ = self.whoami()
        return self._client.get_users_mentions(
            id=user_id,
            since_id=since_id,
            max_results=max(5, min(max_results, 100)),
            tweet_fields=["created_at", "author_id", "conversation_id"],
        )
