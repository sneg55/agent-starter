#!/bin/bash
# Contract tests for hooks/lib/hook-input.sh and hooks/lib/redact.sh.
#
# These are the fixtures the hooks were missing. The old tests set $ARGUMENTS,
# a variable command hooks never receive, so they passed against hooks that
# enforced nothing in production. Everything here drives the real contract:
# one JSON payload on stdin, tool arguments nested under .tool_input.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

BLOCK="$ROOT/hooks/block-dangerous-commands.sh"
SIZE="$ROOT/hooks/check-file-size.sh"
TRACK="$ROOT/hooks/track-reads.sh"

# --- Valid payloads, one per event shape the hooks are wired to -------------

echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push --force"}}' \
  | bash "$BLOCK" 2>/dev/null
assert_eq 2 $? "PreToolUse/Bash: dangerous command blocks"

echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  | bash "$BLOCK" 2>/dev/null
assert_eq 0 $? "PreToolUse/Bash: safe command passes"

tmp=$(mktemp -d); mkdir -p "$tmp/.git" "$tmp/src"; seq 1 301 > "$tmp/src/big.ts"
jq -nc --arg f "$tmp/src/big.ts" \
  '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$f}}' \
  | bash "$SIZE" >/dev/null 2>&1
assert_eq 2 $? "PostToolUse/Edit: oversize file blocks"
rm -rf "$tmp"

# Events with no tool_input at all. These reach the hooks whenever a matcher is
# broader than intended; they must no-op rather than error or enforce.
for ev in \
  '{"hook_event_name":"SessionStart","source":"startup"}' \
  '{"hook_event_name":"UserPromptSubmit","prompt":"hello"}' \
  '{"hook_event_name":"Stop"}' ; do
  name=$(printf '%s' "$ev" | jq -r '.hook_event_name')
  printf '%s' "$ev" | bash "$BLOCK" 2>/dev/null
  assert_eq 0 $? "$name: no tool_input is a no-op, not a block"
done

# --- Missing and unexpected fields -----------------------------------------

echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}' | bash "$BLOCK" 2>/dev/null
assert_eq 0 $? "missing .tool_input.command is a no-op"

echo '{"hook_event_name":"PreToolUse","tool_name":"WebFetch","tool_input":{"url":"https://x"}}' \
  | bash "$BLOCK" 2>/dev/null
assert_eq 0 $? "unexpected tool name is a no-op"

echo '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/nonexistent/x.ts"}}' \
  | bash "$SIZE" 2>/dev/null
assert_eq 0 $? "path that does not exist is a no-op"

# --- Malformed input is loud, and does not block ----------------------------
# Exit 1 shows stderr to the user; exit 2 would block the tool call. A bug in
# the parser must not be able to brick a session, but must not pass silently.

out=$(echo '{"tool_input":{"command":' | bash "$BLOCK" 2>&1); rc=$?
assert_eq 1 "$rc" "truncated JSON exits 1 (loud, non-blocking)"
assert_eq 0 "$(printf '%s' "$out" | grep -qi 'malformed hook input'; echo $?)" \
  "truncated JSON explains itself on stderr"

out=$(echo 'not json at all' | bash "$BLOCK" 2>&1); rc=$?
assert_eq 1 "$rc" "non-JSON input exits 1"
assert_eq 0 "$(printf '%s' "$out" | grep -q 'SKIPPED'; echo $?)" \
  "malformed message says enforcement was skipped"

# Absent input is NOT malformed: a hook invoked outside Claude Code no-ops.
bash "$BLOCK" </dev/null 2>/dev/null
assert_eq 0 $? "empty stdin is a no-op, not an error"

# --- Legacy invocation styles still resolve --------------------------------

ARGUMENTS='{"command":"git push --force"}' bash "$BLOCK" </dev/null 2>/dev/null
assert_eq 2 $? "legacy \$ARGUMENTS with top-level .command still blocks"

bash "$BLOCK" "git push --force" </dev/null 2>/dev/null
assert_eq 2 $? "positional arg still blocks"

# --- track-reads resolves the path from a real Read payload -----------------

tmp=$(mktemp -d); mkdir -p "$tmp/session"; echo hi > "$tmp/f.ts"
jq -nc --arg f "$tmp/f.ts" \
  '{hook_event_name:"PostToolUse",tool_name:"Read",tool_input:{file_path:$f}}' \
  | CLAUDE_SESSION_DIR="$tmp/session" bash "$TRACK"
grep -Fq "$tmp/f.ts" "$tmp/session/read-files.txt" 2>/dev/null
assert_eq 0 $? "track-reads logs the path from .tool_input.file_path"
rm -rf "$tmp"

# --- Redaction: a blocked command must not leak its arguments ---------------
# The blocked command is the one most likely to carry a secret, and the ledger
# is durable on-disk state that /reflect reads back.

tmp=$(mktemp -d); mkdir -p "$tmp/.git"
SECRET="ghp_AAAABBBBCCCCDDDDEEEEFFFF0123456789"
(cd "$tmp" && jq -nc --arg c "git push --force https://$SECRET@github.com/acme/private" \
  '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' \
  | bash "$BLOCK" 2>/dev/null); rc=$?
assert_eq 2 "$rc" "command carrying a token still blocks"
ledger="$tmp/.harness/ledger.jsonl"
assert_eq 1 "$(grep -q "$SECRET" "$ledger" 2>/dev/null; echo $?)" "token is NOT written to the ledger"
assert_eq 1 "$(grep -q 'github.com/acme/private' "$ledger" 2>/dev/null; echo $?)" "private URL is NOT written to the ledger"
detail=$(jq -r '.detail' "$ledger" 2>/dev/null | head -1)
assert_eq 'force_push: git push ...' "$detail" "ledger keeps the reason code and the command shape"
rm -rf "$tmp"

# Opt-in verbose keeps the full command, for local debugging only.
tmp=$(mktemp -d); mkdir -p "$tmp/.git"
(cd "$tmp" && echo '{"tool_input":{"command":"git push --force origin main"}}' \
  | CLAUDE_LEDGER_VERBOSE=1 bash "$BLOCK" 2>/dev/null)
detail=$(jq -r '.detail' "$tmp/.harness/ledger.jsonl" 2>/dev/null | head -1)
assert_eq 'force_push: git push --force origin main' "$detail" "CLAUDE_LEDGER_VERBOSE=1 keeps the full command"
rm -rf "$tmp"

exit "$ASSERT_FAILED"
