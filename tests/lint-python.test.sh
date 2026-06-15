#!/bin/bash
# Tests for the Python (ruff) path in hooks/lint-on-edit.sh.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
HOOK="$ROOT/hooks/lint-on-edit.sh"

# Case 1: .py outside any recognizable project → no-op exit 0.
tmp=$(mktemp -d)
printf 'x = 1\n' > "$tmp/a.py"
ARGUMENTS="{\"file_path\":\"$tmp/a.py\"}" bash "$HOOK"; rc=$?
assert_eq 0 "$rc" "py file outside a project no-ops"
rm -rf "$tmp"

# Case 2 (only when ruff is installed): unfixable error → exit 2 + lint event.
if command -v ruff >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  mkdir -p "$tmp/.git" "$tmp/src"
  printf 'print(undefined_name)\n' > "$tmp/src/bad.py"
  ARGUMENTS="{\"file_path\":\"$tmp/src/bad.py\"}" bash "$HOOK" 2>/dev/null; rc=$?
  assert_eq 2 "$rc" "ruff blocks undefined name"
  rule=$(jq -r '.rule' "$tmp/.harness/ledger.jsonl" 2>/dev/null | head -1)
  assert_eq lint "$rule" "ruff failure logs rule=lint"

  printf 'x = 1\nprint(x)\n' > "$tmp/src/ok.py"
  ARGUMENTS="{\"file_path\":\"$tmp/src/ok.py\"}" bash "$HOOK" 2>/dev/null; rc=$?
  assert_eq 0 "$rc" "ruff passes clean file"

  # Case 3: valid but badly formatted file → exit 0 and reformatted in place.
  printf 'x=1\nprint(x)\n' > "$tmp/src/fmt.py"
  ARGUMENTS="{\"file_path\":\"$tmp/src/fmt.py\"}" bash "$HOOK" 2>/dev/null; rc=$?
  assert_eq 0 "$rc" "ruff format passes valid file"
  assert_eq 'x = 1' "$(head -1 "$tmp/src/fmt.py")" "ruff format rewrote spacing"
  rm -rf "$tmp"
else
  echo "  (ruff not installed - skipping ruff block/pass cases)"
fi

exit $ASSERT_FAILED
