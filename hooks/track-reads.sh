#!/bin/bash
# Claude Code hook: log every Read to a session-scoped file so
# require-read-before-edit.sh can verify a read happened before an edit.
# PostToolUse on Read — always exit 0 (this hook never blocks).
#
# Install: copy to ~/.claude/hooks/, chmod +x, wire in settings.json (see README).

set -u

FILE_PATH=$(echo "${ARGUMENTS:-}" | jq -r '.file_path // .path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

SESSION_DIR="${CLAUDE_SESSION_DIR:-$HOME/.claude/session}"
mkdir -p "$SESSION_DIR"
READ_LOG="$SESSION_DIR/read-files.txt"

ABS_PATH=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && echo "$(pwd)/$(basename "$FILE_PATH")")
[ -z "$ABS_PATH" ] && ABS_PATH="$FILE_PATH"

# Append if not already present. Keep the log small.
grep -Fxq "$ABS_PATH" "$READ_LOG" 2>/dev/null || echo "$ABS_PATH" >> "$READ_LOG"

exit 0
