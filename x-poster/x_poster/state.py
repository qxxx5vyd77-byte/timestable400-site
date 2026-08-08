"""Tiny JSON-file state store.

Tracks the highest mention id we've already seen so the poller only handles
new mentions instead of replaying the whole backlog every run.
"""

from __future__ import annotations

import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
STATE_DIR = PROJECT_ROOT / "state"
MENTIONS_STATE = STATE_DIR / "mentions.json"


def read_since_id() -> str | None:
    if not MENTIONS_STATE.exists():
        return None
    try:
        data = json.loads(MENTIONS_STATE.read_text())
        return data.get("since_id")
    except (json.JSONDecodeError, OSError):
        return None


def write_since_id(since_id: str) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    MENTIONS_STATE.write_text(json.dumps({"since_id": str(since_id)}, indent=2))
