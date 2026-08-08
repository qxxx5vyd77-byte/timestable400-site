"""Configuration loading.

Credentials come from (in priority order):
  1. Environment variables (X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN,
     X_ACCESS_TOKEN_SECRET) -- handy for launchd / CI.
  2. A config.toml file next to the project root.

Keeping secrets out of the code and out of git is the whole point, so there
is no hardcoded fallback -- a missing credential is a hard error.
"""

from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG_PATH = PROJECT_ROOT / "config.toml"


class ConfigError(RuntimeError):
    """Raised when required configuration is missing or malformed."""


@dataclass(frozen=True)
class Config:
    api_key: str
    api_secret: str
    access_token: str
    access_token_secret: str
    mentions_lookback_minutes: int = 60
    dry_run: bool = True

    def redacted(self) -> dict[str, str]:
        """A safe-to-log view -- never print the raw secrets."""

        def mask(value: str) -> str:
            if not value:
                return "<missing>"
            return f"{value[:4]}…{value[-2:]}" if len(value) > 8 else "<set>"

        return {
            "api_key": mask(self.api_key),
            "api_secret": mask(self.api_secret),
            "access_token": mask(self.access_token),
            "access_token_secret": mask(self.access_token_secret),
        }


_ENV_KEYS = {
    "api_key": "X_API_KEY",
    "api_secret": "X_API_SECRET",
    "access_token": "X_ACCESS_TOKEN",
    "access_token_secret": "X_ACCESS_TOKEN_SECRET",
}


def load_config(path: Path | None = None) -> Config:
    """Load config from env vars first, then a TOML file."""

    file_data: dict = {}
    config_path = path or DEFAULT_CONFIG_PATH
    if config_path.exists():
        with config_path.open("rb") as fh:
            file_data = tomllib.load(fh)

    auth = file_data.get("auth", {})
    behavior = file_data.get("behavior", {})

    def resolve(field: str) -> str:
        # Env var wins, then file.
        return os.environ.get(_ENV_KEYS[field]) or auth.get(field, "")

    values = {field: resolve(field) for field in _ENV_KEYS}
    missing = [name for name, val in values.items() if not val or val.startswith("PASTE_")]
    if missing:
        raise ConfigError(
            "Missing X API credentials: "
            + ", ".join(missing)
            + f".\nSet them as env vars ({', '.join(_ENV_KEYS.values())}) "
            + f"or fill in {config_path}."
        )

    return Config(
        api_key=values["api_key"],
        api_secret=values["api_secret"],
        access_token=values["access_token"],
        access_token_secret=values["access_token_secret"],
        mentions_lookback_minutes=int(behavior.get("mentions_lookback_minutes", 60)),
        dry_run=bool(behavior.get("dry_run", True)),
    )
