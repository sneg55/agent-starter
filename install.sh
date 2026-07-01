#!/bin/bash
# Idempotent installer: copies the agent-starter hooks into <claude-dir>/hooks
# and merges their wiring into <claude-dir>/settings.json with jq - no
# hand-editing of JSON.
#
# Usage: ./install.sh [--claude-dir DIR] [--with-read-guard]
#
#   --claude-dir DIR     target Claude config dir (default: ~/.claude)
#   --with-read-guard    also wire track-reads + require-read-before-edit.
#                        Recent Claude Code versions enforce read-before-edit
#                        natively, so this pair is off by default.
#
# Safe to re-run: existing settings entries are preserved; a hook entry is
# added only if its exact command string isn't already present.

set -eu

CLAUDE_DIR="$HOME/.claude"
READ_GUARD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claude-dir) CLAUDE_DIR="${2:?--claude-dir needs a path}"; shift 2 ;;
    --with-read-guard) READ_GUARD=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

REPO=$(cd "$(dirname "$0")" && pwd)
HOOKS_DST="$CLAUDE_DIR/hooks"

mkdir -p "$HOOKS_DST/lib"
cp "$REPO"/hooks/*.sh "$HOOKS_DST/"
cp "$REPO"/hooks/lib/*.sh "$HOOKS_DST/lib/"
chmod +x "$HOOKS_DST"/*.sh "$HOOKS_DST"/lib/*.sh
if [ -f "$REPO/VERSION" ]; then
  cp "$REPO/VERSION" "$HOOKS_DST/.agent-starter-version"
fi

# Use ~ in the wired commands when installing to the default location so the
# entries match the documented snippets; absolute paths otherwise.
if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
  # shellcheck disable=SC2088  # literal ~ wanted: Claude Code expands it at hook run time
  H='~/.claude/hooks'
else
  H="$HOOKS_DST"
fi

SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  printf '{}\n' > "$SETTINGS"
fi
if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "error: $SETTINGS is not valid JSON - fix it before installing" >&2
  exit 1
fi

TMP=$(mktemp)
jq --arg h "$H" --argjson guard "$READ_GUARD" '
  def entry($matcher; $cmd; $t; $msg):
    {matcher: $matcher, hooks: [{type: "command", command: $cmd, timeout: $t, statusMessage: $msg}]};
  def has_cmd($event; $cmd):
    ([ (.hooks[$event] // [])[] | (.hooks // [])[] | .command? ] | index($cmd)) != null;
  def add($event; $e):
    if has_cmd($event; $e.hooks[0].command) then .
    else .hooks[$event] = ((.hooks[$event] // []) + [$e]) end;

  .hooks = (.hooks // {})
  | add("PostToolUse"; entry("Write|Edit"; $h + "/check-file-size.sh"; 5; "Checking file size..."))
  | add("PostToolUse"; entry("Write|Edit"; $h + "/lint-on-edit.sh"; 30; "Linting..."))
  | add("PostToolUse"; entry("Write|Edit"; $h + "/check-silent-errors.sh"; 5; "Checking error handling..."))
  | add("PreToolUse";  entry("Bash"; $h + "/block-dangerous-commands.sh"; 3; "Checking command safety..."))
  | add("SessionStart"; {hooks: [{type: "command", command: ($h + "/check-codebase-health.sh ."), timeout: 15, statusMessage: "Checking codebase health..."}]})
  | add("UserPromptSubmit"; {hooks: [{type: "command", command: ($h + "/suggest-loop-improvements.sh"), timeout: 10, statusMessage: "Reviewing loop/goal instructions..."}]})
  | (if $guard == 1 then
       add("PostToolUse"; entry("Read"; $h + "/track-reads.sh"; 3; "Tracking reads..."))
     | add("PreToolUse";  entry("Edit|Write"; $h + "/require-read-before-edit.sh"; 3; "Checking read log..."))
     else . end)
' "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"

echo "Installed hooks to $HOOKS_DST and wired $SETTINGS"
if [ "$READ_GUARD" -eq 1 ]; then
  echo "Read-guard pair wired (track-reads + require-read-before-edit)"
fi
exit 0
