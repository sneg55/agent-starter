#!/bin/bash

set -eu

usage() {
  cat <<'EOF'
Idempotent installer: copies the agent-starter hooks into <claude-dir>/hooks and
merges their wiring into <claude-dir>/settings.json with jq. Safe to re-run:
existing entries are preserved, and a hook is added only if its exact command
string is not already present.

Usage: ./install.sh [--claude-dir DIR] [--with-read-guard]
                    [--with-comment-guard] [--with-em-dash-guard]

  --claude-dir DIR       target Claude config dir (default: ~/.claude)
  --with-read-guard      also wire track-reads + require-read-before-edit.
                         Recent Claude Code versions enforce read-before-edit
                         natively, so this pair is off by default.
  --with-comment-guard   also wire check-new-comments, which blocks any edit
                         that adds a comment or docstring. Off by default: it
                         is a house style, not a correctness rule.
  --with-em-dash-guard   also wire check-em-dash, which blocks em dashes in
                         .md / .mdx / .markdown files. Off by default, same
                         reason.
EOF
}

CLAUDE_DIR="$HOME/.claude"
READ_GUARD=0
COMMENT_GUARD=0
EM_DASH_GUARD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claude-dir) CLAUDE_DIR="${2:?--claude-dir needs a path}"; shift 2 ;;
    --with-read-guard) READ_GUARD=1; shift ;;
    --with-comment-guard) COMMENT_GUARD=1; shift ;;
    --with-em-dash-guard) EM_DASH_GUARD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }

REPO=$(cd "$(dirname "$0")" && pwd)
HOOKS_DST="$CLAUDE_DIR/hooks"

mkdir -p "$HOOKS_DST/lib"
cp "$REPO"/hooks/*.sh "$REPO"/hooks/*.py "$HOOKS_DST/"
cp "$REPO"/hooks/lib/*.sh "$HOOKS_DST/lib/"
chmod +x "$HOOKS_DST"/*.sh "$HOOKS_DST"/*.py "$HOOKS_DST"/lib/*.sh
if [ -f "$REPO/VERSION" ]; then
  cp "$REPO/VERSION" "$HOOKS_DST/.agent-starter-version"
fi

# Use ~ in the wired commands when installing to the default location so the
# entries match the documented snippets; absolute paths otherwise.
if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
  # shellcheck disable=SC2088  # literal ~ wanted: Claude Code expands it at hook run time
  H='~/.claude/hooks'
  H_INSIDE_DOUBLE_QUOTES='$HOME/.claude/hooks'
else
  H="$HOOKS_DST"
  H_INSIDE_DOUBLE_QUOTES="$HOOKS_DST"
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
jq --arg h "$H" --arg pyh "$H_INSIDE_DOUBLE_QUOTES" --argjson guard "$READ_GUARD" \
   --argjson comments "$COMMENT_GUARD" --argjson emdash "$EM_DASH_GUARD" '
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
  | add("PreToolUse";  entry("Bash"; "python3 \"" + $pyh + "/rm-scope-guard.py\""; 5; "Checking rm scope..."))
  | add("SessionStart"; {hooks: [{type: "command", command: ($h + "/check-codebase-health.sh ."), timeout: 15, statusMessage: "Checking codebase health..."}]})
  | add("SessionStart"; {hooks: [{type: "command", command: ($h + "/worktree-session-prompt.sh"), timeout: 5, statusMessage: "Checking worktree..."}]})
  | add("Stop"; {hooks: [{type: "command", command: ($h + "/worktree-exit-offer.sh"), timeout: 5}]})
  | add("UserPromptSubmit"; {hooks: [{type: "command", command: ($h + "/suggest-loop-improvements.sh"), timeout: 10, statusMessage: "Reviewing loop instructions..."}]})
  | (if $guard == 1 then
       add("PostToolUse"; entry("Read"; $h + "/track-reads.sh"; 3; "Tracking reads..."))
     | add("PreToolUse";  entry("Edit|Write"; $h + "/require-read-before-edit.sh"; 3; "Checking read log..."))
     else . end)
  | (if $comments == 1 then
       add("PreToolUse"; entry("Write|Edit|MultiEdit"; "python3 \"" + $pyh + "/check-new-comments.py\""; 10; "Checking for new comments..."))
     else . end)
  | (if $emdash == 1 then
       add("PostToolUse"; entry("Write|Edit"; "python3 \"" + $pyh + "/check-em-dash.py\""; 10; "Checking for em dashes..."))
     else . end)
' "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"

echo "Installed hooks to $HOOKS_DST and wired $SETTINGS"
if [ "$READ_GUARD" -eq 1 ]; then
  echo "Read-guard pair wired (track-reads + require-read-before-edit)"
fi
if [ "$COMMENT_GUARD" -eq 1 ]; then
  echo "Comment guard wired (check-new-comments)"
fi
if [ "$EM_DASH_GUARD" -eq 1 ]; then
  echo "Em-dash guard wired (check-em-dash)"
fi
exit 0
