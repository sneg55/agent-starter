#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

HOOK="$ROOT/hooks/check-new-comments.py"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

edit() { # file old new -> exit code
  jq -nc --arg f "$1" --arg o "$2" --arg n "$3" \
    '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n}}' \
    | env -u CLAUDE_SKIP_COMMENT_CHECK python3 "$HOOK" >/dev/null 2>&1
  echo $?
}

write() { # file content -> exit code
  jq -nc --arg f "$1" --arg c "$2" \
    '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$f,content:$c}}' \
    | env -u CLAUDE_SKIP_COMMENT_CHECK python3 "$HOOK" >/dev/null 2>&1
  echo $?
}

assert_eq 2 "$(edit "$WORK/a.py" "x = 1" "$(printf '# set the counter\nx = 1')")" \
  "python line comment is blocked"
assert_eq 2 "$(edit "$WORK/a.ts" "const x = 1" "$(printf '// set the counter\nconst x = 1')")" \
  "typescript line comment is blocked"
assert_eq 2 "$(edit "$WORK/a.ts" "const x = 1" "$(printf '/* counter */\nconst x = 1')")" \
  "typescript block comment is blocked"
assert_eq 2 "$(edit "$WORK/a.py" "def f():" "$(printf 'def f():\n    """Return a thing."""')")" \
  "python docstring is blocked"

assert_eq 0 "$(edit "$WORK/a.py" "x = 1" "counter = 1")" "comment-free edit passes"
assert_eq 0 "$(edit "$WORK/a.py" "x = foo()" "x = foo()  # noqa: E501")" "noqa directive passes"
assert_eq 0 "$(edit "$WORK/a.ts" "const x: any = 1" "$(printf '// eslint-disable-next-line\nconst x: any = 1')")" \
  "eslint-disable directive passes"
assert_eq 0 "$(edit "$WORK/a.py" "x = 1" "$(printf '#!/usr/bin/env python3\nx = 1')")" "shebang passes"
assert_eq 0 "$(edit "$WORK/a.py" "$(printf '# old note\nx = 1')" "x = 1")" "deleting a comment passes"
assert_eq 0 "$(edit "$WORK/a.bin" "x" "$(printf '# note\nx')")" "unknown extension is ignored"

assert_eq 2 "$(write "$WORK/new.go" "$(printf '// package main does things\npackage main')")" \
  "Write of a new commented file is blocked"
assert_eq 0 "$(write "$WORK/new.go" "package main")" "Write of a comment-free file passes"

mkdir -p "$WORK/repo/.harness"
git -C "$WORK/repo" init -q
printf '*.generated.ts\n' > "$WORK/repo/.harness/comment-exempt"
assert_eq 0 "$(edit "$WORK/repo/api.generated.ts" "const x = 1" "$(printf '// generated\nconst x = 1')")" \
  "project .harness/comment-exempt glob exempts the file"
assert_eq 2 "$(edit "$WORK/repo/api.ts" "const x = 1" "$(printf '// hand written\nconst x = 1')")" \
  "a non-matching file in the same repo is still checked"

mkdir -p "$WORK/repo/src/generated"
printf 'src/generated/*.ts\n' >> "$WORK/repo/.harness/comment-exempt"
assert_eq 0 "$(edit "$WORK/repo/src/generated/api.ts" "const x = 1" "$(printf '// generated\nconst x = 1')")" \
  "a repo-relative path glob exempts the file"
assert_eq 2 "$(edit "$WORK/repo/src/api.ts" "const x = 1" "$(printf '// hand written\nconst x = 1')")" \
  "a sibling outside the exempt path glob is still checked"

assert_eq 0 "$(jq -nc --arg f "$WORK/a.py" \
  '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"x = 1",new_string:"# note\nx = 1"}}' \
  | CLAUDE_SKIP_COMMENT_CHECK=1 python3 "$HOOK" >/dev/null 2>&1; echo $?)" \
  "CLAUDE_SKIP_COMMENT_CHECK=1 disables the guard"

assert_eq 2 "$(edit "$WORK/a.py" "x = 1" "x = 1  # explanation")" \
  "python trailing comment is blocked"
assert_eq 2 "$(edit "$WORK/a.ts" "const x = 1" "const x = 1; // explanation")" \
  "typescript trailing comment is blocked"
assert_eq 2 "$(edit "$WORK/a.ts" "const x = 1" "const x = 1; /* explanation */")" \
  "typescript trailing block comment is blocked"

assert_eq 0 "$(edit "$WORK/a.ts" "const a = 1" 'const url = "https://example.com/x"')" \
  "a url inside a string is not a trailing comment"
assert_eq 0 "$(edit "$WORK/a.py" "a = 1" 'tag = "# not a comment"')" \
  "a hash inside a string is not a trailing comment"
assert_eq 0 "$(edit "$WORK/a.py" "a = 1" 'path = "a//b"')" \
  "a double slash inside a string is not a trailing comment"
assert_eq 0 "$(edit "$WORK/a.py" "x = foo()" "x = foo()  # noqa: E501")" \
  "a trailing toolchain directive still passes"
assert_eq 0 "$(edit "$WORK/a.py" "x = f()" "x = f()  # type: ignore[arg-type]")" \
  "a trailing type-ignore still passes"

assert_eq 0 "$(printf 'not json' | python3 "$HOOK" >/dev/null 2>&1; echo $?)" \
  "malformed payload fails open"

exit $ASSERT_FAILED
