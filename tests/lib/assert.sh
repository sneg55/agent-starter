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
