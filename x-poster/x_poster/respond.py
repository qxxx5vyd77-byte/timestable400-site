"""Mentions -> reply logic.

This is intentionally simple and rule-based. Edit `decide_reply` to make it do
whatever you want -- keyword routing, canned answers, or later an LLM call.
Returning None means "ignore this mention" (no reply).
"""

from __future__ import annotations

import logging

logger = logging.getLogger("x_poster.respond")


def decide_reply(mention_text: str, author_id: str) -> str | None:
    """Given a mention, return the reply text, or None to stay silent.

    Starter rules -- replace with your own. Kept deliberately conservative so
    the bot never spam-replies to everything by default.
    """
    text = mention_text.lower()

    if "help" in text:
        return (
            "Thanks for reaching out! Docs and links are at "
            "timestable400 — happy to help with anything specific."
        )
    if any(word in text for word in ("thank", "love", "awesome", "great")):
        return "Really appreciate that — thank you! 🙏"

    # Default: do not auto-reply. Better to stay quiet than to post noise.
    return None
