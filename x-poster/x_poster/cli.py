"""Command-line entry point.

Examples:
    python -m x_poster.cli whoami
    python -m x_poster.cli post "hello world"
    python -m x_poster.cli post "with a video" --media ../math-day001.mp4
    python -m x_poster.cli thread "1/ first" "2/ second" "3/ third"
    python -m x_poster.cli mentions --live

Every write defaults to DRY-RUN. Add --live to actually post. This is the
safety net: you can wire up launchd, run the whole pipeline, and confirm the
logs look right before a single real tweet goes out.
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

from .client import XClient
from .config import ConfigError, load_config
from .respond import decide_reply
from .state import read_since_id, write_since_id


def _setup_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def _load(args) -> XClient:
    config = load_config()
    # --live overrides the config's dry_run for this invocation only.
    if getattr(args, "live", False):
        object.__setattr__(config, "dry_run", False)
    if config.dry_run:
        logging.getLogger("x_poster").info("DRY-RUN mode: no real writes will happen")
    return XClient(config)


def cmd_whoami(args) -> int:
    client = _load(args)
    user_id, username = client.whoami()
    print(f"Authenticated as @{username} (id={user_id})")
    return 0


def cmd_post(args) -> int:
    client = _load(args)
    media = [Path(p) for p in (args.media or [])]
    result = client.post(args.text, media_paths=media or None)
    if result.dry_run:
        print(f"[dry-run] would post: {result.text!r}")
    else:
        print(f"posted: {result.url}")
    return 0


def cmd_thread(args) -> int:
    client = _load(args)
    media = [Path(p) for p in (args.media or [])]
    results = client.post_thread(args.parts, media_paths_first=media or None)
    for i, r in enumerate(results, 1):
        if r.dry_run:
            print(f"[dry-run] part {i}: {r.text!r}")
        else:
            print(f"part {i}: {r.url}")
    return 0


def cmd_mentions(args) -> int:
    client = _load(args)
    since_id = read_since_id()
    resp = client.get_mentions(since_id=since_id)
    tweets = resp.data or []
    if not tweets:
        print("no new mentions")
        return 0

    highest = since_id
    # Oldest first so replies go out in order.
    for tweet in reversed(tweets):
        reply = decide_reply(tweet.text, str(tweet.author_id))
        if reply is None:
            print(f"skip mention {tweet.id}: {tweet.text!r}")
        else:
            result = client.post(reply, in_reply_to=str(tweet.id))
            if result.dry_run:
                print(f"[dry-run] would reply to {tweet.id}: {reply!r}")
            else:
                print(f"replied to {tweet.id}: {result.url}")
        highest = str(tweet.id) if highest is None else str(max(int(highest), int(tweet.id)))

    # Only advance the cursor when actually acting for real, so a dry-run
    # doesn't cause you to skip mentions on the first live run.
    if highest and not client._config.dry_run:  # noqa: SLF001 - internal use
        write_since_id(highest)
        print(f"advanced since_id -> {highest}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="x_poster", description="Post to X / handle mentions")
    parser.add_argument("--live", action="store_true", help="actually write (overrides dry_run)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_who = sub.add_parser("whoami", help="verify credentials")
    p_who.set_defaults(func=cmd_whoami)

    p_post = sub.add_parser("post", help="post a single tweet")
    p_post.add_argument("text")
    p_post.add_argument("--media", nargs="*", help="paths to image/video files")
    p_post.set_defaults(func=cmd_post)

    p_thread = sub.add_parser("thread", help="post a thread (one arg per tweet)")
    p_thread.add_argument("parts", nargs="+")
    p_thread.add_argument("--media", nargs="*", help="media attached to the first tweet")
    p_thread.set_defaults(func=cmd_thread)

    p_ment = sub.add_parser("mentions", help="poll mentions and reply per respond.py")
    p_ment.set_defaults(func=cmd_mentions)

    return parser


def main(argv: list[str] | None = None) -> int:
    _setup_logging()
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except ConfigError as e:
        print(f"config error: {e}", file=sys.stderr)
        return 2
    except Exception as e:  # noqa: BLE001 - surface a clean message to the CLI
        logging.getLogger("x_poster").exception("command failed")
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
