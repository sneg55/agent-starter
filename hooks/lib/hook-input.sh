#!/bin/bash
# Shared hook input parser. Source this from every command hook.
#
# Claude Code sends command hooks a JSON payload on stdin, with the tool's own
# arguments nested under .tool_input. There is NO $ARGUMENTS variable for
# command hooks; that placeholder exists only for type: "prompt" hooks, where
# settings.json interpolates it into the prompt string. See
# guides/hooks-reference.md.
#
# Resolution order, highest first:
#   1. a positional argument (CI and direct test invocation pass a bare value)
#   2. $ARGUMENTS (legacy callers)
#   3. one JSON payload on stdin (what Claude Code actually sends)
#
# Checking the positional FIRST matters: a CI caller that passes a path has no
# stdin behind it, and a blocking `cat` would hang the hook until its timeout.
#
# Usage:
#   . "$(dirname "$0")/lib/hook-input.sh"
#   hook_input_init "${1:-}"
#   FILE_PATH=$(hook_input_file)
#   CMD=$(hook_input_command)
#
# Why this is a shared file and not four copies: the same resolution block was
# pasted into each hook, so when it was found to be wrong there was no single
# place to fix it. The fix landed in three hooks and missed three others, which
# stayed silent no-ops. One parser, one place to correct.
#
# Malformed input is LOUD, not silent, and not blocking. hook_input_init exits 1
# when handed non-empty input that is not JSON. Exit 1 surfaces stderr to the
# user without blocking the tool call the way exit 2 would: a bug in this parser
# must never be able to brick a session, but it must never again pass quietly
# either. Silent failure is exactly how three shipped hooks enforced nothing for
# months. Absent input stays exit 0, since that is the legitimate case of a hook
# invoked outside Claude Code.

HOOK_RAW=""
HOOK_BARE=""

hook_input_init() {
  HOOK_BARE="${1:-}"
  [ -n "$HOOK_BARE" ] && return 0

  HOOK_RAW="${ARGUMENTS:-}"
  if [ -z "$HOOK_RAW" ] && [ ! -t 0 ]; then
    HOOK_RAW=$(cat 2>/dev/null)
  fi
  [ -z "$HOOK_RAW" ] && return 0

  if ! printf '%s' "$HOOK_RAW" | jq -e . >/dev/null 2>&1; then
    printf '[%s] malformed hook input: expected a JSON payload on stdin, got %d bytes that do not parse. Enforcement was SKIPPED for this event.\n' \
      "$(basename "$0")" "${#HOOK_RAW}" >&2
    exit 1
  fi
  return 0
}

# Echo the first non-empty value among a `//`-separated list of jq paths.
# A bare positional value short-circuits: it is the value, not a payload.
hook_input_field() {
  if [ -n "$HOOK_BARE" ]; then printf '%s' "$HOOK_BARE"; return 0; fi
  [ -z "$HOOK_RAW" ] && return 0
  printf '%s' "$HOOK_RAW" | jq -r "$1 // empty" 2>/dev/null
}

# The edited/read file. Falls back through the legacy top-level shapes so a
# hand-written $ARGUMENTS fixture keeps working.
hook_input_file() {
  hook_input_field '.tool_input.file_path // .tool_input.path // .file_path // .path'
}

# The shell command for a Bash tool call.
hook_input_command() {
  hook_input_field '.tool_input.command // .command'
}
