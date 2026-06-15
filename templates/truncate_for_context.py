"""Truncate long tool outputs before feeding them back to the LLM.

Problem: `cat large.log`, `rg -l` across a monorepo, or a big test suite can
return tens of thousands of lines. Injecting that verbatim into the
conversation blows the context window and pushes useful history out of cache.

Pattern: always pass tool output through a truncator that keeps a head + tail
window and replaces the middle with a marker the LLM can recognize and reason
about.

Drop into src/utils/ and import from every tool's result formatter.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class TruncateOptions:
    max_chars: int = 32_000  # Hard cap - output is always <= this.
    max_lines: int = 400  # Applied BEFORE the char cap.
    head_lines: int = 200  # Kept from the start when truncating by lines.
    tail_lines: int = 100  # Kept from the end when truncating by lines.
    kind: str = "output"  # Marker label, e.g. "log", "test output".


@dataclass(frozen=True, slots=True)
class TruncateResult:
    text: str
    truncated: bool
    original_lines: int
    original_chars: int


def truncate_for_context(text_in: str, opts: TruncateOptions | None = None) -> TruncateResult:
    o = opts or TruncateOptions()
    original_chars = len(text_in)
    lines = text_in.split("\n")
    original_lines = len(lines)

    text = text_in
    truncated = False

    if len(lines) > o.max_lines:
        head = lines[: o.head_lines]
        tail = lines[-o.tail_lines :]
        elided = len(lines) - o.head_lines - o.tail_lines
        marker = f"[... {elided} lines of {o.kind} elided - total {original_lines} lines ...]"
        text = "\n".join([*head, marker, *tail])
        truncated = True

    if len(text) > o.max_chars:
        half = (o.max_chars - 100) // 2
        elided_chars = len(text) - 2 * half
        text = f"{text[:half]}\n[... {elided_chars} chars elided ...]\n{text[-half:]}"
        truncated = True

    return TruncateResult(
        text=text,
        truncated=truncated,
        original_lines=original_lines,
        original_chars=original_chars,
    )


def format_tool_output(text_in: str, opts: TruncateOptions | None = None) -> str:
    """Truncate and append a summary footer for a tool result block."""
    r = truncate_for_context(text_in, opts)
    if not r.truncated:
        return r.text
    return f"{r.text}\n\n[truncated: {r.original_lines} lines / {r.original_chars} chars total]"
