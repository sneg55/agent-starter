#!/bin/bash
# Integration: the silent-error and read-before-edit hooks log the right rule on block.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

# --- check-silent-errors.sh: empty catch block → exit 2 + silent-error event ---
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
printf 'try {\n  doThing();\n} catch (e) {}\n' > "$tmp/src/bad.ts"
ARGUMENTS="{\"file_path\":\"$tmp/src/bad.ts\"}" bash "$ROOT/hooks/check-silent-errors.sh"; rc=$?
assert_eq 2 "$rc" "silent-error hook blocks empty catch"
rule=$(jq -r '.rule' "$tmp/.harness/ledger.jsonl" | head -1)
assert_eq silent-error "$rule" "silent-error hook logs rule=silent-error"
rm -rf "$tmp"

# --- require-read-before-edit.sh: editing an unread existing file → exit 2 + event ---
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src" "$tmp/session"
: > "$tmp/session/read-files.txt"          # read-log exists but does NOT list our file
echo "existing content" > "$tmp/src/edit.ts"
CLAUDE_SKIP_READ_CHECK=0 CLAUDE_SESSION_DIR="$tmp/session" \
  ARGUMENTS="{\"file_path\":\"$tmp/src/edit.ts\"}" bash "$ROOT/hooks/require-read-before-edit.sh"; rc=$?
assert_eq 2 "$rc" "read-before-edit hook blocks unread file"
rule=$(jq -r '.rule' "$tmp/.harness/ledger.jsonl" | head -1)
assert_eq read-before-edit "$rule" "read-before-edit hook logs rule=read-before-edit"
rm -rf "$tmp"

exit $ASSERT_FAILED
