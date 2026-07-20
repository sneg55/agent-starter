#!/bin/bash
# Minimal assertion helper for the bash test scripts.
# Usage: assert_eq <expected> <actual> <message>
# Sets ASSERT_FAILED=1 on mismatch and prints a diff-ish message.
: "${ASSERT_FAILED:=0}"

assert_eq() {
  if [ "$1" = "$2" ]; then
    return 0
  fi
  ASSERT_FAILED=1
  echo "  ASSERT FAILED: ${3:-<no message>}"
  echo "    expected: [$1]"
  echo "    actual:   [$2]"
  return 1
}

# Build the tool payload Claude Code pipes to a command hook on stdin.
# Usage: payload <file_path> [tool_name] | bash "$HOOK"
# Tests must drive hooks this way: a hook that only reads $ARGUMENTS passes an
# $ARGUMENTS-based test while being a silent no-op in production.
payload() {
  jq -nc --arg f "$1" --arg t "${2:-Edit}" \
    '{hook_event_name:"PostToolUse",tool_name:$t,tool_input:{file_path:$f}}'
}
