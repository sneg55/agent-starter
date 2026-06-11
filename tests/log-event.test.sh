#!/bin/bash
# Tests for hooks/lib/log-event.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
LOG="$ROOT/hooks/lib/log-event.sh"

# Case 1: writes a valid event under the project's .harness/ledger.jsonl
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
"$LOG" file-size block "$tmp/src/a.ts" "312 lines"; rc=$?
assert_eq 0 "$rc" "exits 0 on normal write"
assert_eq 0 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "ledger file created"
lines=$(wc -l < "$tmp/.harness/ledger.jsonl" | tr -d ' ')
assert_eq 1 "$lines" "exactly one event appended"
rule=$(jq -r '.rule' "$tmp/.harness/ledger.jsonl")
assert_eq file-size "$rule" "rule field recorded"
sev=$(jq -r '.severity' "$tmp/.harness/ledger.jsonl")
assert_eq block "$sev" "severity field recorded"
valid=$(jq -e '.ts and .file and (.detail=="312 lines")' "$tmp/.harness/ledger.jsonl" >/dev/null; echo $?)
assert_eq 0 "$valid" "ts/file/detail recorded as valid JSON"
rm -rf "$tmp"

# Case 2: a second call appends rather than overwrites
tmp=$(mktemp -d)
mkdir -p "$tmp/.git"
"$LOG" lint block "$tmp/x.ts" "one" >/dev/null
"$LOG" lint block "$tmp/x.ts" "two" >/dev/null
lines=$(wc -l < "$tmp/.harness/ledger.jsonl" | tr -d ' ')
assert_eq 2 "$lines" "second call appends"
rm -rf "$tmp"

# Case 3: invariant — never fails the caller even with empty/missing args
tmp=$(mktemp -d)
( cd "$tmp" && "$LOG" ); rc=$?
assert_eq 0 "$rc" "exits 0 with no args"
rm -rf "$tmp"

exit $ASSERT_FAILED
