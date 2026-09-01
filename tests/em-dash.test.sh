#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

HOOK="$ROOT/hooks/check-em-dash.py"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

check() { # relative-path -> exit code
  jq -nc --arg f "$WORK/$1" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$f}}' \
    | CLAUDE_PROJECT_DIR="$WORK" python3 "$HOOK" >/dev/null 2>&1
  echo $?
}

printf 'A sentence, then another.\n' > "$WORK/clean.md"
printf 'A sentence \xe2\x80\x94 then another.\n' > "$WORK/dirty.md"
printf 'An mdx page \xe2\x80\x94 with one.\n' > "$WORK/dirty.mdx"
printf 'A bar \xe2\x80\x95 here.\n' > "$WORK/bar.markdown"
printf 'A range 2020-2024 and an en dash \xe2\x80\x93 stay.\n' > "$WORK/dashes.md"
printf 'code \xe2\x80\x94 here\n' > "$WORK/code.ts"
mkdir -p "$WORK/.harness"
printf 'ledger note \xe2\x80\x94 here\n' > "$WORK/.harness/note.md"

assert_eq 0 "$(check clean.md)" "clean markdown passes"
assert_eq 2 "$(check dirty.md)" "em dash in .md is blocked"
assert_eq 2 "$(check dirty.mdx)" "em dash in .mdx is blocked"
assert_eq 2 "$(check bar.markdown)" "horizontal bar in .markdown is blocked"
assert_eq 0 "$(check dashes.md)" "en dash and hyphens are not flagged"
assert_eq 0 "$(check code.ts)" "non-prose extension is ignored"
assert_eq 0 "$(check .harness/note.md)" "harness scratch is exempt"
assert_eq 0 "$(check missing.md)" "missing file fails open"

outside=$(mktemp -d)
printf 'outside \xe2\x80\x94 here\n' > "$outside/doc.md"
assert_eq 0 "$(jq -nc --arg f "$outside/doc.md" \
  '{tool_name:"Write",tool_input:{file_path:$f}}' \
  | CLAUDE_PROJECT_DIR="$WORK" python3 "$HOOK" >/dev/null 2>&1; echo $?)" \
  "a file outside the project is not this project's business"
rm -rf "$outside"

assert_eq 0 "$(printf 'not json' | python3 "$HOOK" >/dev/null 2>&1; echo $?)" \
  "malformed payload fails open"

exit $ASSERT_FAILED
