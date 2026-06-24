#!/bin/bash
# Claude Code hook: enforce file size limits
# PostToolUse on Write|Edit - exit 2 to block, exit 0 to pass
# (wire to both: files can grow past the limit through repeated Edits)
#
# Install: copy to ~/.claude/hooks/ and add to settings.json
# The hook receives tool arguments via $ARGUMENTS

# Resolve the edited file path across the three invocation styles. CI passes it
# as a positional arg; Claude Code pipes the tool payload as JSON on stdin (path
# under .tool_input.file_path); legacy callers set $ARGUMENTS. Check $1 FIRST so
# the CI path never reads stdin (a blocking `cat` would hang there). Reading only
# $ARGUMENTS made this a silent no-op under Claude Code, which uses stdin.
FILE_PATH="${1:-}"
if [ -z "$FILE_PATH" ]; then
  HOOK_INPUT="${ARGUMENTS:-}"
  if [ -z "$HOOK_INPUT" ] && [ ! -t 0 ]; then
    HOOK_INPUT=$(cat 2>/dev/null)
  fi
  FILE_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // .path // empty' 2>/dev/null)
fi

# Skip if we can't determine the file
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Skip non-code files
case "$FILE_PATH" in
  *.md|*.json|*.yaml|*.yml|*.toml|*.lock|*.svg|*.png|*.jpg|*.csv|*.txt)
    exit 0
    ;;
esac

LINE_COUNT=$(wc -l < "$FILE_PATH" | tr -d ' ')
WARN_THRESHOLD=200
BLOCK_THRESHOLD=300

if [ "$LINE_COUNT" -gt "$BLOCK_THRESHOLD" ]; then
  cat >&2 <<EOF
⛔ FILE TOO LARGE: $FILE_PATH has $LINE_COUNT lines (limit: $BLOCK_THRESHOLD)

This file exceeds the maximum size. You MUST split it before proceeding.

Split by concern - extract into separate files:
- types.ts / types.py - type definitions and interfaces
- constants.ts / constants.py - named constants and config values  
- validation.ts / validation.py - input validation logic
- utils.ts / utils.py - pure helper functions
- [Name].test.ts - tests (always separate)

Each extracted file should be under 200 lines and handle a single responsibility.
Do NOT just move code around - ensure clean imports and no circular dependencies.
EOF
  [ -x "$(dirname "$0")/lib/log-event.sh" ] && "$(dirname "$0")/lib/log-event.sh" file-size block "$FILE_PATH" "$LINE_COUNT lines (limit $BLOCK_THRESHOLD)"
  exit 2

elif [ "$LINE_COUNT" -gt "$WARN_THRESHOLD" ]; then
  cat >&2 <<EOF
⚠️ FILE GETTING LARGE: $FILE_PATH has $LINE_COUNT lines (target: <$WARN_THRESHOLD)

Consider splitting soon. Look for:
- Type definitions → extract to types.ts
- Constants/config → extract to constants.ts  
- Validation logic → extract to validation.ts
- Helper functions → extract to utils.ts
- Distinct feature blocks → extract to their own module
EOF
  [ -x "$(dirname "$0")/lib/log-event.sh" ] && "$(dirname "$0")/lib/log-event.sh" file-size warn "$FILE_PATH" "$LINE_COUNT lines (target <$WARN_THRESHOLD)"
  exit 0
fi

exit 0
