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

# Case 4 (only when mypy is installed): opt-in type-check via marker file.
if command -v mypy >/dev/null 2>&1; then
  # A type error that ruff cannot catch (valid syntax, defined names).
  tmp=$(mktemp -d)
  mkdir -p "$tmp/.git" "$tmp/src"
  printf 'x: int = "not an int"\nprint(x)\n' > "$tmp/src/typeerr.py"

  # Without the marker: type errors pass (gate is closed).
  ARGUMENTS="{\"file_path\":\"$tmp/src/typeerr.py\"}" bash "$HOOK" 2>/dev/null; rc=$?
  assert_eq 0 "$rc" "mypy does not run without the enable-typecheck-on-edit marker"

  # With the marker: mypy blocks the type error.
  mkdir -p "$tmp/.claude" && touch "$tmp/.claude/enable-typecheck-on-edit"
  ARGUMENTS="{\"file_path\":\"$tmp/src/typeerr.py\"}" bash "$HOOK" 2>/dev/null; rc=$?
  assert_eq 2 "$rc" "mypy blocks type error when marker present"
  rule=$(jq -r '.rule' "$tmp/.harness/ledger.jsonl" 2>/dev/null | head -1)
  assert_eq lint "$rule" "mypy failure logs rule=lint"

  # A type-clean file passes even with the marker.
  printf 'y: int = 1\nprint(y)\n' > "$tmp/src/clean.py"
  ARGUMENTS="{\"file_path\":\"$tmp/src/clean.py\"}" bash "$HOOK" 2>/dev/null; rc=$?
  assert_eq 0 "$rc" "mypy passes a type-clean file"
  rm -rf "$tmp"
else
  echo "  (mypy not installed - skipping mypy typecheck cases)"
fi

exit $ASSERT_FAILED
