"""Central error ID registry. See guides/error-id-registry.md.

Rules:
  1. Never reuse a retired ID - mark it `# retired` and leave it in place.
  2. One ID per distinct cause, not per raise site.
  3. Numbers are stable; append, never renumber.
  4. Domain prefix (3-5 letters) is required.

Raise via AppError(ErrorIds.X, "...", {...}). Log lines include the ID so
grep, telemetry, and agents can all find every occurrence with one search.
"""

from __future__ import annotations

import json
from enum import StrEnum
from typing import Any


class ErrorIds(StrEnum):
    # ── Config (CFG) ─────────────────────────────────────────────────────────
    CFG_MISSING = "E_CFG_001"
    CFG_INVALID_JSON = "E_CFG_002"
    CFG_SCHEMA_FAIL = "E_CFG_003"
    CFG_ENV_MISSING = "E_CFG_004"

    # ── Filesystem (FS) ──────────────────────────────────────────────────────
    FS_NOT_FOUND = "E_FS_001"
    FS_PERMISSION = "E_FS_002"
    FS_DISK_FULL = "E_FS_003"
    FS_READ_FAIL = "E_FS_004"
    FS_WRITE_FAIL = "E_FS_005"

    # ── Network (NET) ────────────────────────────────────────────────────────
    NET_TIMEOUT = "E_NET_001"
    NET_DNS = "E_NET_002"
    NET_TLS = "E_NET_003"
    NET_RATE_LIMITED = "E_NET_004"
    NET_UNAVAILABLE = "E_NET_005"
    NET_BAD_SHAPE = "E_NET_006"

    # ── Tool execution (TOOL) ────────────────────────────────────────────────
    TOOL_ABORTED = "E_TOOL_001"
    TOOL_BAD_INPUT = "E_TOOL_002"
    TOOL_TIMEOUT = "E_TOOL_003"
    TOOL_PERMISSION_DENIED = "E_TOOL_004"
    TOOL_SECURITY_BLOCKED = "E_TOOL_005"

    # ── LLM / API (LLM) ──────────────────────────────────────────────────────
    LLM_RATE_LIMITED = "E_LLM_001"
    LLM_CONTEXT_OVERFLOW = "E_LLM_002"
    LLM_BAD_RESPONSE = "E_LLM_003"

    # Add new domains/IDs below. Keep the comment block above each domain.


class AppError(Exception):
    """Base error: every raise carries a stable ID plus structured context."""

    def __init__(
        self,
        error_id: ErrorIds,
        message: str,
        context: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.id = error_id
        self.context = context or {}

    def to_log_line(self) -> str:
        ctx = " ".join(f"{k}={json.dumps(v, default=str)}" for k, v in self.context.items())
        return f"[{self.id}] {self}{' ' + ctx if ctx else ''}"
