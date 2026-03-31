#!/bin/bash
# Claude Code hook: enforce file size limits
# PostToolUse on Write — exit 2 to block, exit 0 to pass
#
# Install: copy to ~/.claude/hooks/ and add to settings.json
# The hook receives tool arguments via $ARGUMENTS

# Extract file path from hook input
FILE_PATH=$(echo "$ARGUMENTS" | jq -r '.file_path // .path // empty' 2>/dev/null)

# Fallback: try to get it from positional args
if [ -z "$FILE_PATH" ]; then
  FILE_PATH="$1"
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

Split by concern — extract into separate files:
- types.ts / types.py — type definitions and interfaces
- constants.ts / constants.py — named constants and config values  
- validation.ts / validation.py — input validation logic
- utils.ts / utils.py — pure helper functions
- [Name].test.ts — tests (always separate)

Each extracted file should be under 200 lines and handle a single responsibility.
Do NOT just move code around — ensure clean imports and no circular dependencies.
EOF
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
  exit 0
fi

exit 0
