#!/bin/bash
# Claude Code hook: log every Read to a session-scoped file so
# require-read-before-edit.sh can verify a read happened before an edit.
# PostToolUse on Read - always exit 0 (this hook never blocks).
#
# Install: copy to ~/.claude/hooks/, chmod +x, wire in settings.json (see README).

set -u

# Resolve the read file path across the three invocation styles. CI passes it as
# a positional arg; Claude Code pipes the tool payload as JSON on stdin (path
# under .tool_input.file_path); legacy callers set $ARGUMENTS. Check $1 FIRST so
# the CI path never reads stdin (a blocking `cat` would hang there). Reading only
# $ARGUMENTS made this a silent no-op under Claude Code, which uses stdin: the
# read log was never written, so require-read-before-edit.sh always failed open.
FILE_PATH="${1:-}"
if [ -z "$FILE_PATH" ]; then
  HOOK_INPUT="${ARGUMENTS:-}"
  if [ -z "$HOOK_INPUT" ] && [ ! -t 0 ]; then
    HOOK_INPUT=$(cat 2>/dev/null)
  fi
  FILE_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // .path // empty' 2>/dev/null)
fi
[ -z "$FILE_PATH" ] && exit 0

SESSION_DIR="${CLAUDE_SESSION_DIR:-$HOME/.claude/session}"
mkdir -p "$SESSION_DIR"
READ_LOG="$SESSION_DIR/read-files.txt"

ABS_PATH=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && echo "$(pwd)/$(basename "$FILE_PATH")")
[ -z "$ABS_PATH" ] && ABS_PATH="$FILE_PATH"

# Append if not already present. Keep the log small.
grep -Fxq "$ABS_PATH" "$READ_LOG" 2>/dev/null || echo "$ABS_PATH" >> "$READ_LOG"

exit 0
