#!/usr/bin/env python3
import fnmatch
import json
import os
import subprocess
import sys

from comment_syntax import (
    BLOCK_COMMENT_EXTENSIONS,
    BLOCK_COMMENT_PREFIXES,
    DOCSTRING_OPENERS,
    FILENAME_PREFIXES,
    LINE_COMMENT_PREFIXES,
    TOOLCHAIN_DIRECTIVE,
)

EXEMPT_BASENAME = "comment-exempt"
MAX_REPORTED = 12
HOOK_DIR = os.path.dirname(os.path.abspath(__file__))


def log_event(file_path, detail):
    script = os.path.join(HOOK_DIR, "lib", "log-event.sh")
    if not os.access(script, os.X_OK):
        return
    try:
        subprocess.run(
            [script, "no-new-comments", "block", file_path, detail],
            timeout=5,
            check=False,
            capture_output=True,
        )
    except (OSError, subprocess.SubprocessError):
        return


def repo_root(file_path):
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=os.path.dirname(os.path.abspath(file_path)),
            timeout=5,
            check=False,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout.strip() or None


def exempt_globs(file_path):
    candidates = [os.path.expanduser("~/.claude/" + EXEMPT_BASENAME)]
    root = repo_root(file_path)
    if root:
        candidates.append(os.path.join(root, ".harness", EXEMPT_BASENAME))
    globs = []
    for candidate in candidates:
        try:
            with open(candidate, encoding="utf-8") as handle:
                globs.extend(
                    line.strip()
                    for line in handle
                    if line.strip() and not line.startswith("#")
                )
        except OSError:  # silent-ok
            continue
    return globs


def candidate_paths(file_path):
    absolute = os.path.abspath(file_path)
    paths = [file_path, absolute, os.path.basename(file_path)]
    root = repo_root(file_path)
    if root:
        try:
            relative = os.path.relpath(os.path.realpath(absolute), os.path.realpath(root))
        except ValueError:  # silent-ok
            return paths
        if not relative.startswith(".."):
            paths.append(relative)
    return paths


def is_exempt(file_path):
    if os.environ.get("CLAUDE_SKIP_COMMENT_CHECK"):
        return True
    paths = candidate_paths(file_path)
    for glob in exempt_globs(file_path):
        if any(fnmatch.fnmatch(path, glob) for path in paths):
            return True
    return False


def comment_prefixes(file_path):
    name = os.path.basename(file_path)
    if name in FILENAME_PREFIXES:
        return FILENAME_PREFIXES[name], False
    extension = os.path.splitext(name)[1].lower()
    if extension not in LINE_COMMENT_PREFIXES:
        return None, False
    return LINE_COMMENT_PREFIXES[extension], extension in BLOCK_COMMENT_EXTENSIONS


def added_lines(tool_name, tool_input):
    if tool_name == "Write":
        try:
            with open(tool_input.get("file_path", ""), encoding="utf-8") as handle:
                old_text = handle.read()
        except OSError:
            old_text = ""
        return difference(old_text, tool_input.get("content", ""))
    if tool_name == "Edit":
        return difference(tool_input.get("old_string", ""), tool_input.get("new_string", ""))
    if tool_name == "MultiEdit":
        out = []
        for edit in tool_input.get("edits", []):
            out.extend(difference(edit.get("old_string", ""), edit.get("new_string", "")))
        return out
    return []


def difference(old_text, new_text):
    old_counts = {}
    for line in old_text.splitlines():
        old_counts[line] = old_counts.get(line, 0) + 1
    out = []
    for number, line in enumerate(new_text.splitlines(), start=1):
        if old_counts.get(line):
            old_counts[line] -= 1
            continue
        out.append((number, line))
    return out


def is_python_docstring(stripped, previous_stripped):
    if not stripped.startswith(DOCSTRING_OPENERS):
        return False
    if previous_stripped is None:
        return True
    return previous_stripped.endswith(":") or previous_stripped == ""


def blank_quoted(line):
    out = []
    quote = None
    index = 0
    while index < len(line):
        character = line[index]
        if quote:
            if character == "\\":
                out.append("_")
                index += 1
                if index < len(line):
                    out.append("_")
                    index += 1
                continue
            out.append("_" if character != quote else character)
            if character == quote:
                quote = None
        else:
            if character in "\"'`":
                quote = character
            out.append(character)
        index += 1
    return "".join(out)


def trailing_comment(line, prefixes, has_blocks):
    masked = blank_quoted(line)
    starts = [masked.find(prefix) for prefix in tuple(prefixes) + (("/*",) if has_blocks else ())]
    starts = [position for position in starts if position > 0]
    if not starts:
        return None
    position = min(starts)
    if masked[:position].strip() == "":
        return None
    return line[position:].strip()


def find_comments(lines, prefixes, has_blocks, is_python):
    hits = []
    previous_stripped = None
    for number, line in lines:
        stripped = line.strip()
        if not stripped:
            previous_stripped = stripped
            continue
        flagged = bool(prefixes) and stripped.startswith(prefixes)
        if not flagged and has_blocks and stripped.startswith(BLOCK_COMMENT_PREFIXES):
            flagged = True
        if not flagged and is_python and is_python_docstring(stripped, previous_stripped):
            flagged = True
        if flagged:
            if not TOOLCHAIN_DIRECTIVE.search(stripped):
                hits.append((number, stripped))
            previous_stripped = stripped
            continue
        tail = trailing_comment(line, prefixes, has_blocks)
        if tail and not TOOLCHAIN_DIRECTIVE.search(tail):
            hits.append((number, stripped))
        previous_stripped = stripped
    return hits


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    tool_input = payload.get("tool_input", {}) or {}
    file_path = tool_input.get("file_path", "")
    if not file_path or is_exempt(file_path):
        return 0
    prefixes, has_blocks = comment_prefixes(file_path)
    if prefixes is None:
        return 0
    is_python = os.path.splitext(file_path)[1].lower() in (".py", ".pyi")
    lines = added_lines(payload.get("tool_name", ""), tool_input)
    hits = find_comments(lines, prefixes, has_blocks, is_python)
    if not hits:
        return 0

    log_event(file_path, f"{len(hits)} comment line(s)")
    print(
        f"Blocked: this edit adds {len(hits)} comment line(s) to {os.path.basename(file_path)}, "
        "and this project's rule is zero comments in code (no headers, no one-liners, no "
        "docstrings, no notes beside a constant).",
        file=sys.stderr,
    )
    for number, text in hits[:MAX_REPORTED]:
        print(f"  +{number}: {text[:120]}", file=sys.stderr)
    if len(hits) > MAX_REPORTED:
        print(f"  ... and {len(hits) - MAX_REPORTED} more", file=sys.stderr)
    print(
        "\nRewrite so the code carries the meaning: a name, a type, a named constant, a small "
        "function, or a test whose name states the constraint. An external reason (a spec "
        "requirement, an empirical threshold, a cross-repo invariant) goes in a doc, not here. "
        "Reflowing or rewording an existing comment counts as adding one; deleting comments is "
        "always allowed. Toolchain directives pass on their own (noqa, type: ignore, "
        "eslint-disable, shebangs, SPDX). To exempt a path, add a glob to "
        ".harness/comment-exempt (or ~/.claude/comment-exempt); to disable entirely, set "
        "CLAUDE_SKIP_COMMENT_CHECK=1.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
