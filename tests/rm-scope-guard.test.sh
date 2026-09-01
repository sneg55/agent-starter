#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

HOOK="$ROOT/hooks/rm-scope-guard.py"
WORK=$(mktemp -d)
mkdir -p "$WORK/sub"
trap 'rm -rf "$WORK"' EXIT

RM=$(printf 'r%s' m)

run_guard() { # command -> prints exit code
  jq -nc --arg c "$1" --arg d "$WORK" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' \
    | CLAUDE_ALLOW_DANGEROUS=0 python3 "$HOOK" >/dev/null 2>&1
  echo $?
}

assert_eq 0 "$(run_guard "$RM -rf build")" "relative target inside cwd is allowed"
assert_eq 0 "$(run_guard "$RM -rf ./dist/bundle.js")" "dot-slash target inside cwd is allowed"
assert_eq 0 "$(run_guard "cd sub && $RM -rf tmp")" "target inside cwd after cd is allowed"
assert_eq 0 "$(run_guard "$RM -rf $WORK/sub")" "absolute target inside cwd is allowed"

assert_eq 2 "$(run_guard "$RM -rf ../sibling")" "parent escape is blocked"
assert_eq 2 "$(run_guard "$RM -rf /etc/hosts")" "absolute target outside cwd is blocked"
assert_eq 2 "$(run_guard "sudo $RM -rf /var/log/app")" "sudo form is blocked"
assert_eq 2 "$(run_guard "$RM -rf \$HOME/Documents")" "tilde-equivalent home escape is blocked"
assert_eq 2 "$(run_guard "$RM -rf ~/Documents")" "tilde escape is blocked"

assert_eq 0 "$(run_guard "ssh host 'cd /opt/app && $RM -rf cache'")" \
  "remote payload inside quotes is not judged against the local cwd"
assert_eq 0 "$(run_guard "git commit -m 'drop the old parser'")" "unrelated command passes"
assert_eq 0 "$(run_guard "ls | xargs $RM")" "dynamically built rm passes through unchecked"
assert_eq 0 "$(run_guard "$RM -rf $WORK")" "cwd itself is allowed"

assert_eq 0 "$(jq -nc --arg c "$RM -rf /etc/hosts" --arg d "$WORK" \
  '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' \
  | CLAUDE_ALLOW_DANGEROUS=1 python3 "$HOOK" >/dev/null 2>&1; echo $?)" \
  "CLAUDE_ALLOW_DANGEROUS=1 disables the guard"

assert_eq 2 "$(run_guard "cd .. && $RM -rf sibling")" \
  "cd out of the tree before rm is blocked"
assert_eq 2 "$(run_guard "cd /etc && $RM -rf hosts")" \
  "cd to an absolute path before rm is blocked"
assert_eq 0 "$(run_guard "cd sub && $RM -rf ../sub")" \
  "cd then a relative target still inside the boundary is allowed"

assert_eq 2 "$(run_guard "sudo -n $RM -rf /var/lib/app")" "sudo with flags is blocked"
assert_eq 2 "$(run_guard "command $RM -rf ../sibling")" "command wrapper is blocked"
assert_eq 2 "$(run_guard "env $RM -rf ../sibling")" "env wrapper is blocked"
assert_eq 2 "$(run_guard "\\\\$RM -rf ../sibling")" "backslash-escaped rm is blocked"
assert_eq 2 "$(run_guard "/bin/$RM -rf ../sibling")" "absolute rm path is blocked"

assert_eq 2 "$(run_guard "cd - && $RM -rf sibling")" \
  "an unknowable cd makes a relative target escaping"
assert_eq 2 "$(run_guard "cd - x && $RM -rf /etc/hosts")" \
  "an unknowable cd does not let an absolute target through"

assert_eq 0 "$(run_guard "$RM -f build.log >/dev/null")" \
  "a redirection operand is not an rm target"
assert_eq 0 "$(run_guard "$RM -f build.log 2>/dev/null")" \
  "a numbered redirection operand is not an rm target"
assert_eq 2 "$(run_guard "$RM -rf ../sibling >/dev/null")" \
  "redirection does not hide a real escape"

assert_eq 0 "$(printf 'not json' | python3 "$HOOK" >/dev/null 2>&1; echo $?)" \
  "malformed payload fails open"

exit $ASSERT_FAILED
