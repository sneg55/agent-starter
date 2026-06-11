#!/bin/bash
# Regression: file-size hook still blocks >300 lines AND now logs an event.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
HOOK="$ROOT/hooks/check-file-size.sh"

# Block path: 301-line .ts file → exit 2 + one file-size event logged.
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 301 > "$tmp/src/big.ts"
ARGUMENTS="{\"file_path\":\"$tmp/src/big.ts\"}" bash "$HOOK"; rc=$?
assert_eq 2 "$rc" "blocks file >300 lines"
assert_eq 0 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "ledger written on block"
rule=$(jq -r '.rule' "$tmp/.harness/ledger.jsonl" | head -1)
assert_eq file-size "$rule" "logged rule is file-size"
sev=$(jq -r '.severity' "$tmp/.harness/ledger.jsonl" | head -1)
assert_eq block "$sev" "logged severity is block"
rm -rf "$tmp"

# Pass path: small .ts file → exit 0, no event.
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 10 > "$tmp/src/ok.ts"
ARGUMENTS="{\"file_path\":\"$tmp/src/ok.ts\"}" bash "$HOOK"; rc=$?
assert_eq 0 "$rc" "passes small file"
assert_eq 1 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "no ledger for passing file"
rm -rf "$tmp"

# Warn path: 250-line .ts file → exit 0 + a file-size event with severity=warn.
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 250 > "$tmp/src/warn.ts"
ARGUMENTS="{\"file_path\":\"$tmp/src/warn.ts\"}" bash "$HOOK"; rc=$?
assert_eq 0 "$rc" "warn path exits 0 (does not block)"
assert_eq 0 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "ledger written on warn"
sev=$(jq -r '.severity' "$tmp/.harness/ledger.jsonl" | head -1)
assert_eq warn "$sev" "logged severity is warn"
rm -rf "$tmp"

exit $ASSERT_FAILED
