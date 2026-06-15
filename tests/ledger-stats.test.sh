#!/bin/bash
# Tests for hooks/harness-ledger-stats.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
STATS="$ROOT/hooks/harness-ledger-stats.sh"
FIX="$ROOT/tests/fixtures/ledger.jsonl"

# Case 1: whole ledger, min-recurr 3. The 3 file-size events in src/parsers cluster.
got=$(bash "$STATS" --ledger "$FIX" --min-recurr 3)
want="events_total 5
events_window 5
by_rule file-size 3
by_rule lint 1
by_rule silent-error 1
recurring file-size src/parsers 3
recurring_events 3"
assert_eq "$want" "$got" "full ledger stats"

# Case 2: windowed since 2026-06-03 - only 3 events in window, no cluster reaches 3.
got=$(bash "$STATS" --ledger "$FIX" --min-recurr 3 --since 2026-06-03T00:00:00Z)
want="events_total 5
events_window 3
by_rule file-size 1
by_rule lint 1
by_rule silent-error 1
recurring_events 0"
assert_eq "$want" "$got" "windowed stats"

# Case 3: missing ledger → zeros, exit 0.
got=$(bash "$STATS" --ledger "$ROOT/tests/fixtures/does-not-exist.jsonl"); rc=$?
want="events_total 0
events_window 0
recurring_events 0"
assert_eq 0 "$rc" "missing ledger exits 0"
assert_eq "$want" "$got" "missing ledger zeros"

# Case 4: default --min-recurr (3) matches the explicit value.
got=$(bash "$STATS" --ledger "$FIX")
want="events_total 5
events_window 5
by_rule file-size 3
by_rule lint 1
by_rule silent-error 1
recurring file-size src/parsers 3
recurring_events 3"
assert_eq "$want" "$got" "default min-recurr equals explicit 3"

# Case 5: empty (but existing) ledger file → zeros, exit 0.
empty=$(mktemp)
got=$(bash "$STATS" --ledger "$empty"); rc=$?
want="events_total 0
events_window 0
recurring_events 0"
assert_eq 0 "$rc" "empty ledger exits 0"
assert_eq "$want" "$got" "empty ledger zeros"
rm -f "$empty"

# Case 6: a value-less trailing flag must not hang (regression for the shift-2 fix).
timeout 5 bash "$STATS" --ledger "$FIX" --since >/dev/null 2>&1; rc=$?
assert_eq 0 "$rc" "trailing valueless flag does not hang"

exit $ASSERT_FAILED
