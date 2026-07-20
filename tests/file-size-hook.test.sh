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
payload "$tmp/src/big.ts" | bash "$HOOK"; rc=$?
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
payload "$tmp/src/ok.ts" | bash "$HOOK"; rc=$?
assert_eq 0 "$rc" "passes small file"
assert_eq 1 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "no ledger for passing file"
rm -rf "$tmp"

# Warn path: 250-line .ts file → exit 0 + a file-size event with severity=warn.
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 250 > "$tmp/src/warn.ts"
payload "$tmp/src/warn.ts" | bash "$HOOK"; rc=$?
assert_eq 0 "$rc" "warn path exits 0 (does not block)"
assert_eq 0 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "ledger written on warn"
sev=$(jq -r '.severity' "$tmp/.harness/ledger.jsonl" | head -1)
assert_eq warn "$sev" "logged severity is warn"
rm -rf "$tmp"


# Stylesheets get their own, looser tier: they have no types/constants/helpers to
# extract, and 200 lines is tight for one-declaration-per-line CSS. warn 250 / block 400.

# CSS at 240 lines: under the stylesheet warn threshold, so it passes (a .ts would warn).
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 240 > "$tmp/src/ok.css"
payload "$tmp/src/ok.css" | bash "$HOOK"; rc=$?
assert_eq 0 "$rc" "240-line stylesheet passes"
assert_eq 1 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "no event for a passing stylesheet"
rm -rf "$tmp"

# CSS at 260 lines: warns, does not block.
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 260 > "$tmp/src/warn.css"
payload "$tmp/src/warn.css" | bash "$HOOK"; rc=$?
assert_eq 0 "$rc" "260-line stylesheet warns without blocking"
sev=$(jq -r '.severity' "$tmp/.harness/ledger.jsonl" | head -1)
assert_eq warn "$sev" "stylesheet warn logged"
rm -rf "$tmp"

# CSS at 401 lines: blocks, and the advice is split-by-layer, not extract-types.ts.
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 401 > "$tmp/src/huge.css"
out=$(payload "$tmp/src/huge.css" | bash "$HOOK" 2>&1); rc=$?
assert_eq 2 "$rc" "blocks stylesheet >400 lines"
assert_eq 0 "$(printf '%s' "$out" | grep -qi 'Split by layer'; echo $?)" "stylesheet advice is split-by-layer"
assert_eq 1 "$(printf '%s' "$out" | grep -q 'types.ts'; echo $?)" "stylesheet advice does not mention types.ts"
rm -rf "$tmp"

# A .ts file is unaffected by the stylesheet tier: 301 lines still blocks at 300.
tmp=$(mktemp -d)
mkdir -p "$tmp/.git" "$tmp/src"
seq 1 301 > "$tmp/src/big.ts"
out=$(payload "$tmp/src/big.ts" | bash "$HOOK" 2>&1); rc=$?
assert_eq 2 "$rc" "ts threshold unchanged at 300"
assert_eq 0 "$(printf '%s' "$out" | grep -q 'types.ts'; echo $?)" "module advice still names types.ts"
rm -rf "$tmp"

exit $ASSERT_FAILED
