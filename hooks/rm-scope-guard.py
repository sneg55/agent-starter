#!/usr/bin/env python3
import json
import os
import re
import shlex
import subprocess
import sys

SEPARATORS = {";", "&", "&&", "|", "||", "\n"}
REDIRECTIONS = {">", ">>", "<", "<<", "<<<", "&>", ">&", "2>", "2>>", "1>", "1>>"}
WRAPPERS = {"sudo", "command", "env", "builtin", "exec", "time", "nice", "ionice", "doas"}
RM_NAMES = {"rm", "\\rm", "/bin/rm", "/usr/bin/rm"}
RM_PATTERN = re.compile(r"(^|[^\w./-])\\?/?(?:usr/)?(?:bin/)?rm(\s|$|;|&|\|)")
MAX_REPORTED = 8


def log_event(target, detail):
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib", "log-event.sh")
    if not os.access(script, os.X_OK):
        return
    try:
        subprocess.run(
            [script, "rm-scope", "block", target, detail],
            timeout=5,
            check=False,
            capture_output=True,
        )
    except (OSError, subprocess.SubprocessError):
        return


def tokenize(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:
        return command.split()


def strip_redirections(tokens):
    out = []
    skip_next = False
    for token in tokens:
        if skip_next:
            skip_next = False
            continue
        if token in REDIRECTIONS:
            skip_next = True
            continue
        if len(token) > 1 and token[0] in "<>" or (
            len(token) > 2 and token[0].isdigit() and token[1] in "<>"
        ):
            continue
        out.append(token)
    return out


def rm_arguments(segment):
    for index, token in enumerate(segment):
        if token in RM_NAMES:
            return segment[index + 1 :]
    return None


def next_directory(segment, cwd):
    if not segment or segment[0] != "cd":
        return cwd
    if "-" in segment[1:]:
        return None
    targets = [t for t in segment[1:] if not t.startswith("-")]
    if not targets:
        return os.path.realpath(os.path.expanduser("~"))
    if cwd is None:
        return None
    return os.path.realpath(os.path.join(cwd, os.path.expanduser(targets[0])))


def rm_invocations(command, cwd):
    segment = []
    for token in tokenize(command) + [";"]:
        if token in SEPARATORS:
            clean = strip_redirections(segment)
            arguments = rm_arguments(clean)
            if arguments is not None:
                yield arguments, cwd
            cwd = next_directory(clean, cwd)
            segment = []
            continue
        segment.append(token)


def escapes(argument, resolve_dir, boundary):
    expanded = os.path.expanduser(argument)
    for form in ("${HOME}", "$HOME"):
        expanded = expanded.replace(form, os.path.expanduser("~"))
    if resolve_dir is None and not os.path.isabs(expanded):
        return True
    if os.path.isabs(expanded):
        target = expanded
    else:
        target = os.path.join(resolve_dir, expanded)
    target = os.path.realpath(target)
    if target == boundary:
        return False
    return not target.startswith(boundary + os.sep)


def main():
    if os.environ.get("CLAUDE_ALLOW_DANGEROUS") == "1":
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    command = (payload.get("tool_input", {}) or {}).get("command", "") or ""
    if not command or not RM_PATTERN.search(command):
        return 0

    boundary = payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    boundary = os.path.realpath(boundary)

    saw_rm = False
    escaping = []
    for arguments, resolve_dir in rm_invocations(command, boundary):
        saw_rm = True
        for argument in arguments:
            if argument == "--" or argument.startswith("-"):
                continue
            if escapes(argument, resolve_dir, boundary):
                escaping.append(argument)

    if not saw_rm or not escaping:
        return 0

    log_event(escaping[0], f"{len(escaping)} target(s) outside cwd")
    print(
        f"Blocked: rm target outside the working directory ({boundary}).",
        file=sys.stderr,
    )
    for argument in escaping[:MAX_REPORTED]:
        print(f"  {argument}", file=sys.stderr)
    if len(escaping) > MAX_REPORTED:
        print(f"  ... and {len(escaping) - MAX_REPORTED} more", file=sys.stderr)
    print(
        "\nDeleting outside the project is unrecoverable and is almost never what the task "
        "asked for. Move the path into a project-local .trash/ directory instead, re-run the "
        "rm from a shell outside Claude, or set CLAUDE_ALLOW_DANGEROUS=1 for a session that "
        "genuinely needs it.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
