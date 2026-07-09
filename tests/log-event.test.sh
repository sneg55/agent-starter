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

# Case 3: invariant - never fails the caller even with empty/missing args
tmp=$(mktemp -d)
( cd "$tmp" && "$LOG" ); rc=$?
assert_eq 0 "$rc" "exits 0 with no args"
rm -rf "$tmp"


# Case 4: the path is stored relative to the project root. Absolute paths make every
# event cluster under one useless "/Users" prefix in harness-ledger-stats.sh.
tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P)
mkdir -p "$tmp/.git" "$tmp/src"
"$LOG" file-size warn "$tmp/src/a.ts" "240 lines" >/dev/null
file=$(jq -r '.file' "$tmp/.harness/ledger.jsonl")
assert_eq "src/a.ts" "$file" "path stored relative to project root"
rm -rf "$tmp"

# Case 5: a workspace member does not fork the ledger. Walking up for the FIRST
# package.json stops inside web/, writing web/.harness/ and hiding half the signal.
tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P)
mkdir -p "$tmp/.git" "$tmp/web/src"
echo '{}' > "$tmp/package.json"
echo '{}' > "$tmp/web/package.json"
"$LOG" file-size warn "$tmp/web/src/a.css" "260 lines" >/dev/null
assert_eq 0 "$([ -f "$tmp/.harness/ledger.jsonl" ]; echo $?)" "ledger at repo root"
assert_eq 1 "$([ -f "$tmp/web/.harness/ledger.jsonl" ]; echo $?)" "no forked ledger in workspace member"
file=$(jq -r '.file' "$tmp/.harness/ledger.jsonl")
assert_eq "web/src/a.css" "$file" "workspace path relative to repo root"
rm -rf "$tmp"

# Case 6: an exact duplicate is rejected. A hook registered twice (once by a plugin,
# once in settings.json) fires twice per edit and doubles every count, corrupting the
# metric /reflect reports. Identical second + rule + file + detail is that duplicate.
tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P)
mkdir -p "$tmp/.git"
"$LOG" file-size warn "$tmp/a.ts" "240 lines" >/dev/null
"$LOG" file-size warn "$tmp/a.ts" "240 lines" >/dev/null
lines=$(wc -l < "$tmp/.harness/ledger.jsonl" | tr -d ' ')
assert_eq 1 "$lines" "exact duplicate append rejected"
# ...but a genuinely different event still appends.
"$LOG" file-size warn "$tmp/a.ts" "241 lines" >/dev/null
lines=$(wc -l < "$tmp/.harness/ledger.jsonl" | tr -d ' ')
assert_eq 2 "$lines" "a differing event still appends"
rm -rf "$tmp"

exit $ASSERT_FAILED
