"""Single env boundary. See guides/zod-at-the-boundary.md (Python section).

Rules:
  1. This file is the ONLY place environment variables are read.
     (Grep for `os.environ` in review; nothing outside this file may use it.)
  2. The Env model is the source of truth for the config type.
  3. Validation happens at import time - fail fast on misconfiguration.
  4. Add new vars here, declare their shape, provide a default where sensible.

Consumers:
    from app.env import env
    client.get(env.api_url, timeout=env.timeout_s)

Requires: pydantic >= 2, pydantic-settings.
"""

from __future__ import annotations

import sys
from typing import Literal

from pydantic import Field, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict


class Env(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # ── Runtime ──────────────────────────────────────────────────────────────
    app_env: Literal["development", "test", "production"] = "development"
    port: int = Field(default=3000, gt=0)
    log_level: Literal["debug", "info", "warning", "error"] = "info"

    # ── External services (examples - replace with your own) ─────────────────
    # (noqa ERA001: these are intentional commented examples, not dead code)
    # database_url: PostgresDsn  # noqa: ERA001
    # redis_url: RedisDsn | None = None  # noqa: ERA001
    # anthropic_api_key: SecretStr  # noqa: ERA001
    # sentry_dsn: HttpUrl | None = None  # noqa: ERA001


def _load_env() -> Env:
    try:
        return Env()
    except ValidationError as e:
        # Render a readable error at startup. One bad env var should surface the
        # exact field and reason, not crash 10 stack frames deep.
        lines = [f"  {'.'.join(str(p) for p in err['loc'])}: {err['msg']}" for err in e.errors()]
        print(  # noqa: T201 - startup error; must reach stderr.
            "[env] invalid configuration:\n" + "\n".join(lines),
            file=sys.stderr,
        )
        raise SystemExit(1) from e


env = _load_env()
