#!/bin/bash
# Reduce a shell command to a shape that is safe to keep in the ledger.
#
# Why: a blocked command is the one most likely to carry something sensitive.
# It can hold an API token, a signed URL, a database password, customer data, or
# inline file contents. `.harness/ledger.jsonl` is a durable on-disk artifact
# that /reflect and harness-ledger-stats.sh read back, so storing the raw
# command there turns a safety rejection into a secret at rest.
#
# What survives by default: the first two words. That is the command's shape
# ("git push", "rm -rf"), which is all /reflect needs to spot a repeated
# pattern, and it cannot carry an argument. Everything after is dropped.
#
# Set CLAUDE_LEDGER_VERBOSE=1 to store the full command instead. That is a
# local-only debugging aid, and it is off by default on purpose.

redact_command() {
  if [ "${CLAUDE_LEDGER_VERBOSE:-0}" = "1" ]; then
    printf '%s' "$1"
    return 0
  fi
  # First line only: a multi-line command's later lines are pure payload.
  printf '%s' "$1" | head -n 1 | awk '{ if (NF > 2) print $1" "$2" ..."; else print }'
}
