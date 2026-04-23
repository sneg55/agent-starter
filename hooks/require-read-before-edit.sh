#!/bin/bash
# Claude Code hook: block Edit/Write on files the agent hasn't read this session.
# PreToolUse on Edit|Write — exit 2 blocks with stderr, exit 0 allows.
#
# Why: LLMs routinely edit files based on guesses rather than the current
# contents. Forcing a Read before Edit catches hallucinated edits before
# they corrupt files.
#
# How it works: maintains a session-scoped file at
# $CLAUDE_SESSION_DIR/read-files.txt that other hooks append to when Read
# is called. This hook checks the target is in that list.
#
# Companion hook: track-reads.sh (PostToolUse on Read). Both must be installed.
#
# Exemptions:
#   - Writing a NEW file (doesn't exist yet) is allowed.
#   - Files under paths matching .claude/read-before-edit-exempt (one pattern per line).
#   - Set CLAUDE_SKIP_READ_CHECK=1 to disable entirely.
#
# Install: copy to ~/.claude/hooks/, chmod +x, wire in settings.json (see README).

set -u

[ "${CLAUDE_SKIP_READ_CHECK:-0}" = "1" ] && exit 0

FILE_PATH=$(echo "${ARGUMENTS:-}" | jq -r '.file_path // .path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# New files are fine — you can't read something that doesn't exist.
[ ! -f "$FILE_PATH" ] && exit 0

SESSION_DIR="${CLAUDE_SESSION_DIR:-$HOME/.claude/session}"
READ_LOG="$SESSION_DIR/read-files.txt"

# If the log doesn't exist, the companion hook isn't installed. Fail open
# with a warning on stderr (exit 0 so we don't block unrelated work).
if [ ! -f "$READ_LOG" ]; then
  echo "[require-read-before-edit] warning: $READ_LOG not found; install track-reads.sh" >&2
  exit 0
fi

# Check exemptions.
PROJECT_ROOT=""
DIR=$(cd "$(dirname "$FILE_PATH")" && pwd)
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/.claude" ] || [ -f "$DIR/package.json" ] || [ -d "$DIR/.git" ]; then
    PROJECT_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

EXEMPT_FILE="$PROJECT_ROOT/.claude/read-before-edit-exempt"
if [ -f "$EXEMPT_FILE" ]; then
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$FILE_PATH" in
      $pattern) exit 0 ;;
    esac
  done < "$EXEMPT_FILE"
fi

# Normalize to an absolute path for comparison.
ABS_PATH=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && echo "$(pwd)/$(basename "$FILE_PATH")")
[ -z "$ABS_PATH" ] && ABS_PATH="$FILE_PATH"

if ! grep -Fxq "$ABS_PATH" "$READ_LOG" 2>/dev/null; then
  cat >&2 <<EOF
Blocked: must Read $FILE_PATH before Edit/Write in this session.

Why: editing a file you haven't read leads to hallucinated changes that
contradict its current contents. Read the file first, then retry the edit.

To exempt a path, add a glob to .claude/read-before-edit-exempt
(one per line). To disable entirely, set CLAUDE_SKIP_READ_CHECK=1.
EOF
  exit 2
fi

exit 0
