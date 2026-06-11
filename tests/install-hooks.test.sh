#!/bin/bash
# Tests for install.sh — idempotent hook copy + settings.json merge.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
INSTALL="$ROOT/install.sh"

# Case 1: fresh install into an empty dir
tmp=$(mktemp -d)
bash "$INSTALL" --claude-dir "$tmp/.claude" >/dev/null; rc=$?
assert_eq 0 "$rc" "fresh install exits 0"
assert_eq 0 "$([ -x "$tmp/.claude/hooks/check-file-size.sh" ]; echo $?)" "hooks copied executable"
assert_eq 0 "$([ -x "$tmp/.claude/hooks/lib/log-event.sh" ]; echo $?)" "lib helper copied"
n=$(jq '[.hooks.PostToolUse[].hooks[].command] | length' "$tmp/.claude/settings.json")
assert_eq 3 "$n" "three PostToolUse hooks wired"
pre=$(jq '[.hooks.PreToolUse[].hooks[].command] | length' "$tmp/.claude/settings.json")
assert_eq 1 "$pre" "dangerous-commands wired in PreToolUse"
guard=$(jq '[.hooks.PreToolUse[].hooks[].command | select(test("require-read-before-edit"))] | length' "$tmp/.claude/settings.json")
assert_eq 0 "$guard" "read guard not wired by default"
ver=$(cat "$tmp/.claude/hooks/.agent-starter-version" 2>/dev/null)
assert_eq "$(cat "$ROOT/VERSION")" "$ver" "version stamped"

# Case 2: re-running adds no duplicates
bash "$INSTALL" --claude-dir "$tmp/.claude" >/dev/null
n=$(jq '[.hooks.PostToolUse[].hooks[].command] | length' "$tmp/.claude/settings.json")
assert_eq 3 "$n" "re-run is idempotent"
rm -rf "$tmp"

# Case 3: preserves unrelated settings and custom hook entries
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
cat > "$tmp/.claude/settings.json" <<'EOF'
{"model":"opus","hooks":{"PostToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"/custom/hook.sh"}]}]}}
EOF
bash "$INSTALL" --claude-dir "$tmp/.claude" >/dev/null
model=$(jq -r '.model' "$tmp/.claude/settings.json")
assert_eq opus "$model" "unrelated keys preserved"
custom=$(jq '[.hooks.PostToolUse[].hooks[].command | select(. == "/custom/hook.sh")] | length' "$tmp/.claude/settings.json")
assert_eq 1 "$custom" "existing custom hook preserved"
n=$(jq '[.hooks.PostToolUse[].hooks[].command] | length' "$tmp/.claude/settings.json")
assert_eq 4 "$n" "3 new entries + 1 existing"
rm -rf "$tmp"

# Case 4: --with-read-guard wires the pair
tmp=$(mktemp -d)
bash "$INSTALL" --claude-dir "$tmp/.claude" --with-read-guard >/dev/null
guard=$(jq '[.hooks.PreToolUse[].hooks[].command | select(test("require-read-before-edit"))] | length' "$tmp/.claude/settings.json")
assert_eq 1 "$guard" "read guard wired with flag"
track=$(jq '[.hooks.PostToolUse[].hooks[].command | select(test("track-reads"))] | length' "$tmp/.claude/settings.json")
assert_eq 1 "$track" "track-reads wired with flag"
rm -rf "$tmp"

# Case 5: refuses to touch invalid settings.json
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
echo '{not json' > "$tmp/.claude/settings.json"
bash "$INSTALL" --claude-dir "$tmp/.claude" >/dev/null 2>&1; rc=$?
assert_eq 1 "$rc" "invalid settings.json refused"
assert_eq "{not json" "$(cat "$tmp/.claude/settings.json")" "invalid file left untouched"
rm -rf "$tmp"

exit $ASSERT_FAILED
