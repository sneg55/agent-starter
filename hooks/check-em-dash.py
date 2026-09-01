#!/usr/bin/env python3
import json
import os
import subprocess
import sys

EM_DASH = "—"
HORIZONTAL_BAR = "―"
BANNED = (EM_DASH, HORIZONTAL_BAR)
PROSE_EXTENSIONS = (".md", ".markdown", ".mdx")
SCRATCH_DIRS = {".superpowers", ".harness", "node_modules"}
MAX_REPORTED = 25
HOOK_DIR = os.path.dirname(os.path.abspath(__file__))


def log_event(file_path, detail):
    script = os.path.join(HOOK_DIR, "lib", "log-event.sh")
    if not os.access(script, os.X_OK):
        return
    try:
        subprocess.run(
            [script, "em-dash", "block", file_path, detail],
            timeout=5,
            check=False,
            capture_output=True,
        )
    except (OSError, subprocess.SubprocessError):
        return


def in_project_scratch(file_path):
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if not project_dir:
        return False
    try:
        real = os.path.realpath(file_path)
        root = os.path.realpath(project_dir)
        if os.path.commonpath([real, root]) != root:
            return True
        return bool(SCRATCH_DIRS & set(os.path.relpath(real, root).split(os.sep)))
    except (ValueError, OSError):
        return True


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    file_path = (payload.get("tool_input", {}) or {}).get("file_path", "")
    if not file_path.lower().endswith(PROSE_EXTENSIONS):
        return 0
    if in_project_scratch(file_path):
        return 0

    try:
        with open(file_path, encoding="utf-8") as handle:
            lines = handle.readlines()
    except (OSError, UnicodeDecodeError):
        return 0

    hits = [
        (number, line.rstrip("\n"))
        for number, line in enumerate(lines, start=1)
        if any(character in line for character in BANNED)
    ]
    if not hits:
        return 0

    log_event(file_path, f"{len(hits)} em dash(es)")
    print(
        f"Blocked: {len(hits)} em dash(es) in {os.path.basename(file_path)}. "
        "Replace each with a comma, a colon, parentheses, or two sentences.",
        file=sys.stderr,
    )
    for number, text in hits[:MAX_REPORTED]:
        print(f"  L{number}: {text.strip()[:120]}", file=sys.stderr)
    if len(hits) > MAX_REPORTED:
        print(f"  ... and {len(hits) - MAX_REPORTED} more", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
