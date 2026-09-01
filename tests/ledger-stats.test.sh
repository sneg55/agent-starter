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

WORK=$(cd "$(mktemp -d)" && pwd -P)
MAIN="$WORK/main"
git init -q "$MAIN"
git -C "$MAIN" config user.email t@example.com
git -C "$MAIN" config user.name test
printf 'seed\n' > "$MAIN/README.md"
git -C "$MAIN" add README.md
git -C "$MAIN" commit -qm seed
mkdir -p "$MAIN/.harness"
event() { jq -nc --arg r "$1" --arg f "$2" '{ts:"2026-06-01T00:00:00Z",rule:$r,severity:"block",file:$f,detail:"d"}'; }
for _ in 1 2; do event file-size src/parsers/a.ts >> "$MAIN/.harness/ledger.jsonl"; done

LINKED="$WORK/feature"
git -C "$MAIN" worktree add -q -b feature "$LINKED"
mkdir -p "$LINKED/.harness"
event file-size src/parsers/b.ts >> "$LINKED/.harness/ledger.jsonl"

got=$(cd "$MAIN" && bash "$STATS" --min-recurr 3)
assert_eq "recurring file-size src/parsers 3" "$(printf '%s' "$got" | grep '^recurring file-size')" \
  "linked worktree ledgers are merged into one cluster"
assert_eq "events_total 3" "$(printf '%s' "$got" | grep '^events_total')" \
  "events from every checkout are counted"

event file-size "$MAIN/src/parsers/c.ts" >> "$MAIN/.harness/ledger.jsonl"
got=$(cd "$MAIN" && bash "$STATS" --min-recurr 4)
assert_eq "recurring file-size src/parsers 4" "$(printf '%s' "$got" | grep '^recurring file-size')" \
  "an absolute path normalizes to the same repo-relative cluster"

got=$(cd "$MAIN" && bash "$STATS" --ledger "$FIX")
assert_eq "events_total 5" "$(printf '%s' "$got" | grep '^events_total')" \
  "an explicit --ledger reads that file alone"

SPACED="$WORK/dir with spaces"
mkdir -p "$SPACED"
cp "$FIX" "$SPACED/ledger.jsonl"
got=$(bash "$STATS" --ledger "$SPACED/ledger.jsonl" 2>/dev/null)
assert_eq "events_total 5" "$(printf '%s' "$got" | grep '^events_total')" \
  "a ledger path containing spaces is not word-split"

git -C "$MAIN" worktree remove --force "$LINKED"
rm -rf "$WORK"

exit $ASSERT_FAILED
