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

  # Project root. Prefer the git toplevel: walking up for the FIRST directory that
  # has a package.json stops inside workspace members (e.g. web/), which forks the
  # ledger into web/.harness/ and hides half the signal from /reflect.
  if [ -n "$FILE" ] && [ -d "$(dirname "$FILE")" ]; then
    DIR=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd)
  else
    DIR=$(pwd)
  fi
  ROOT=$(cd "$DIR" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)

  # `git rev-parse` fails on a .git that is only a marker (no HEAD), and on any
  # non-repo tree. Fall back to the .git marker itself, innermost wins: that is the
  # repo boundary, and it never escapes into a parent dotfiles repo.
  if [ -z "$ROOT" ]; then
    SEARCH="$DIR"
    while [ -n "$SEARCH" ] && [ "$SEARCH" != "/" ] && [ "$SEARCH" != "$HOME" ]; do
      if [ -e "$SEARCH/.git" ]; then ROOT="$SEARCH"; break; fi
      SEARCH=$(dirname "$SEARCH")
    done
  fi

  # No .git anywhere: use the OUTERMOST package.json / .claude marker, not the
  # innermost. The innermost stops inside a workspace member (e.g. web/), which forks
  # the ledger into web/.harness/ and hides half the signal from /reflect. Bounded at
  # $HOME so a stray ~/package.json cannot swallow every project.
  if [ -z "$ROOT" ]; then
    SEARCH="$DIR"
    while [ -n "$SEARCH" ] && [ "$SEARCH" != "/" ] && [ "$SEARCH" != "$HOME" ]; do
      if [ -f "$SEARCH/package.json" ] || [ -d "$SEARCH/.claude" ]; then
        ROOT="$SEARCH"
      fi
      SEARCH=$(dirname "$SEARCH")
    done
  fi

  [ -z "$ROOT" ] && ROOT=$(pwd)

  # Store the path relative to the root. Absolute paths make every event cluster
  # under a single useless "/Users" prefix in harness-ledger-stats.sh.
  # Resolve FILE physically first: `git rev-parse` yields a physical path, so on
  # macOS a /tmp (-> /private/tmp) path would never match the ROOT prefix.
  if [ -n "$FILE" ] && [ -d "$(dirname "$FILE")" ]; then
    FILE="$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P)/$(basename "$FILE")"
  fi
  case "$FILE" in
    "$ROOT"/*) FILE="${FILE#"$ROOT"/}" ;;
  esac

  LEDGER_DIR="$ROOT/.harness"
  mkdir -p "$LEDGER_DIR" 2>/dev/null
  LEDGER="$LEDGER_DIR/ledger.jsonl"

  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  LINE=$(jq -cn \
    --arg ts "$TS" \
    --arg rule "$RULE" \
    --arg severity "$SEVERITY" \
    --arg file "$FILE" \
    --arg detail "$DETAIL" \
    --arg session "${CLAUDE_SESSION_ID:-}" \
    '{ts:$ts, rule:$rule, severity:$severity, file:$file, detail:$detail, session:$session}' 2>/dev/null)

  # A hook registered twice (e.g. by a plugin AND by settings.json) fires twice per
  # edit and doubles every count, corrupting the metric /reflect reports. Same
  # second + same rule + same file + same detail is that duplicate, not a real
  # second event: a human cannot trigger the identical check twice within one second.
  if [ -n "$LINE" ]; then
    if [ ! -s "$LEDGER" ] || [ "$(tail -n 1 "$LEDGER" 2>/dev/null)" != "$LINE" ]; then
      printf '%s\n' "$LINE" >> "$LEDGER" 2>/dev/null
    fi
  fi
} 2>/dev/null || true

exit 0
