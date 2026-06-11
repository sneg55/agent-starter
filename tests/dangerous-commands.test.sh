#!/bin/bash
# Tests for hooks/block-dangerous-commands.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
HOOK="$ROOT/hooks/block-dangerous-commands.sh"

run() {
  ARGUMENTS="{\"command\":$(printf '%s' "$1" | jq -Rs .)}" bash "$HOOK" 2>/dev/null
}

run "git push --force origin main"; assert_eq 2 $? "blocks git push --force"
run "git push -f"; assert_eq 2 $? "blocks git push -f"
run "git push --force-with-lease origin main"; assert_eq 0 $? "allows --force-with-lease"
run "git push origin main"; assert_eq 0 $? "allows normal push"
run "git reset --hard HEAD~1"; assert_eq 2 $? "blocks git reset --hard"
run "git reset --soft HEAD~1"; assert_eq 0 $? "allows git reset --soft"
run "git clean -fd"; assert_eq 2 $? "blocks git clean -fd"
run "git checkout -- ."; assert_eq 2 $? "blocks git checkout -- ."
run "git restore ."; assert_eq 2 $? "blocks git restore ."
run "git restore .gitignore"; assert_eq 0 $? "allows git restore <file>"
run "rm -rf /"; assert_eq 2 $? "blocks rm -rf /"
run "rm -rf ~"; assert_eq 2 $? "blocks rm -rf ~"
run 'rm -rf $HOME'; assert_eq 2 $? "blocks rm -rf \$HOME"
run "rm -rf ./build"; assert_eq 0 $? "allows rm -rf ./build"
run "rm -rf /tmp/scratch"; assert_eq 0 $? "allows rm -rf /tmp/scratch"
run "chmod -R 777 /"; assert_eq 2 $? "blocks chmod -R 777 /"
run "ls -la"; assert_eq 0 $? "allows ls"

# Escape hatch
CLAUDE_ALLOW_DANGEROUS=1 ARGUMENTS='{"command":"git push --force"}' bash "$HOOK" 2>/dev/null
assert_eq 0 $? "CLAUDE_ALLOW_DANGEROUS=1 disables the hook"

# Logs a dangerous-command event in the project ledger (root found from cwd)
tmp=$(mktemp -d)
mkdir -p "$tmp/.git"
(cd "$tmp" && ARGUMENTS='{"command":"git reset --hard"}' bash "$HOOK" 2>/dev/null); rc=$?
assert_eq 2 "$rc" "blocks inside tmp project"
rule=$(jq -r '.rule' "$tmp/.harness/ledger.jsonl" 2>/dev/null | head -1)
assert_eq dangerous-command "$rule" "logs rule=dangerous-command"
rm -rf "$tmp"

exit $ASSERT_FAILED
