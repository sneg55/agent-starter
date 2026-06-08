#!/bin/bash
# Append one structured event to the project's .harness/ledger.jsonl.
# Usage: log-event.sh <rule> <severity> <file> <detail>
#
# Invariant: BEST-EFFORT. This script must never fail the hook that calls it.
# It swallows all of its own errors and always exits 0. If .harness/ can't be
# created or jq is missing, the calling hook still performs its real check.
# silent-ok: the swallow below is intentional and required by that invariant.

{
  RULE="${1:-unknown}"
  SEVERITY="${2:-info}"
  FILE="${3:-}"
  DETAIL="${4:-}"

  # Find the project root by walking up for a .git / package.json / .claude marker.
  if [ -n "$FILE" ] && [ -d "$(dirname "$FILE")" ]; then
    DIR=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd)
  else
    DIR=$(pwd)
  fi
  ROOT=""
  while [ -n "$DIR" ] && [ "$DIR" != "/" ]; do
    if [ -d "$DIR/.git" ] || [ -f "$DIR/package.json" ] || [ -d "$DIR/.claude" ]; then
      ROOT="$DIR"; break
    fi
    DIR=$(dirname "$DIR")
  done
  [ -z "$ROOT" ] && ROOT=$(pwd)

  LEDGER_DIR="$ROOT/.harness"
  mkdir -p "$LEDGER_DIR" 2>/dev/null

  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -cn \
    --arg ts "$TS" \
    --arg rule "$RULE" \
    --arg severity "$SEVERITY" \
    --arg file "$FILE" \
    --arg detail "$DETAIL" \
    --arg session "${CLAUDE_SESSION_ID:-}" \
    '{ts:$ts, rule:$rule, severity:$severity, file:$file, detail:$detail, session:$session}' \
    >> "$LEDGER_DIR/ledger.jsonl" 2>/dev/null
} 2>/dev/null || true

exit 0
