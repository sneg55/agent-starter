#!/bin/bash
# Deterministic stats over a .harness/ledger.jsonl ledger.
# Usage: harness-ledger-stats.sh [--ledger PATH] [--since ISO8601] [--min-recurr N]
#
# Output (token-separated, one record per line):
#   events_total <int>
#   events_window <int>
#   by_rule <rule> <int>             (sorted by rule asc)
#   recurring <rule> <prefix> <int>  (clusters with count >= min-recurr, sorted)
#   recurring_events <int>
#
# "window" = events with ts >= --since (all events if --since omitted).
# "prefix" = first two path segments of the file field.
# Unparseable ledger lines are skipped, not fatal.
set -u

LEDGER=".harness/ledger.jsonl"
LEDGER_EXPLICIT=0
SINCE=""
MINR=3
while [ $# -gt 0 ]; do
  case "$1" in
    --ledger)     LEDGER="${2:-}"; LEDGER_EXPLICIT=1; shift $(( $# >= 2 ? 2 : 1 )) ;;
    --since)      SINCE="${2:-}";  shift $(( $# >= 2 ? 2 : 1 )) ;;
    --min-recurr) MINR="${2:-3}";  shift $(( $# >= 2 ? 2 : 1 )) ;;
    *) shift ;;
  esac
done

case "$MINR" in
  ''|*[!0-9]*) echo "error: --min-recurr must be a non-negative integer" >&2; exit 1 ;;
esac

if [ -n "$SINCE" ]; then
  case "$SINCE" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) ;;
    *) echo "warning: --since should be ISO-8601 UTC (e.g. 2026-06-03T00:00:00Z); got: $SINCE" >&2 ;;
  esac
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
LEDGERS=()
if [ "$LEDGER_EXPLICIT" -eq 1 ] || [ -z "$REPO_ROOT" ]; then
  [ -f "$LEDGER" ] && LEDGERS=("$LEDGER")
else
  while IFS= read -r wt; do
    [ -f "$wt/.harness/ledger.jsonl" ] && LEDGERS+=("$wt/.harness/ledger.jsonl")
  done < <(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
fi

if [ "${#LEDGERS[@]}" -eq 0 ]; then
  printf 'events_total 0\nevents_window 0\nrecurring_events 0\n'
  exit 0
fi

MAIN_CHECKOUT=$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -1)
[ -z "$MAIN_CHECKOUT" ] && MAIN_CHECKOUT="${REPO_ROOT:-.}"

cat "${LEDGERS[@]}" | jq -nRr --arg since "$SINCE" --argjson minr "$MINR" --arg root "$MAIN_CHECKOUT" '
  [ inputs
    | (fromjson? // empty)
    | select(type == "object" and .rule != null)
    | . + { file: ((.file // "")
                   | ltrimstr($root + "/")
                   | sub("^\\.claude/worktrees/[^/]+/"; "")) }
    | . + { prefix: (.file | split("/") | .[0:2] | join("/")) }
  ] as $all
  | ( if $since == "" then $all
      else [ $all[] | select((.ts // "") >= $since) ] end ) as $win
  | ( $win | group_by(.rule)
      | map({rule: .[0].rule, n: length}) | sort_by(.rule) ) as $byrule
  | ( $win | group_by([.rule, .prefix])
      | map({rule: .[0].rule, prefix: .[0].prefix, n: length})
      | map(select(.n >= $minr)) | sort_by([.rule, .prefix]) ) as $rec
  | ( [ "events_total \($all | length)",
        "events_window \($win | length)" ]
      + ( $byrule | map("by_rule \(.rule) \(.n)") )
      + ( $rec    | map("recurring \(.rule) \(.prefix) \(.n)") )
      + [ "recurring_events \(($rec | map(.n) | add) // 0)" ] )
  | .[]
'
