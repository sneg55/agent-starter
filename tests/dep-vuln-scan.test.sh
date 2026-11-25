#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

SCAN="$ROOT/skills/dep-vuln-update/scripts/scan.py"
PY=$(command -v python3)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/home" "$WORK/repo" "$WORK/untracked" "$WORK/elsewhere"
REPO=$(cd "$WORK/repo" && pwd -P)

git -C "$REPO" init -q
printf '{}\n' > "$REPO/package-lock.json"
git -C "$REPO" add package-lock.json
git -C "$WORK/untracked" init -q
printf '{}\n' > "$WORK/untracked/package-lock.json"

jq -n --arg src "$REPO/package-lock.json" '{results: [{source: {path: $src}, packages: [{
  package: {name: "lodash", version: "4.17.20", ecosystem: "npm"},
  vulnerabilities: [{id: "GHSA-test-0000-0001", summary: "stub advisory",
    database_specific: {severity: "HIGH"},
    affected: [{package: {name: "lodash", ecosystem: "npm"},
      ranges: [{type: "SEMVER", events: [{introduced: "0"}, {fixed: "4.17.21"}]}]}]}],
  groups: [{ids: ["GHSA-test-0000-0001"], aliases: ["CVE-0000-0001"], max_severity: "7.5"}]}]}]}' \
  > "$WORK/osv.json"

printf '#!/bin/sh\ncat "%s"\nexit 1\n' "$WORK/osv.json" > "$WORK/bin/osv-scanner"
chmod +x "$WORK/bin/osv-scanner"

STUB_PATH="$WORK/bin:/usr/bin:/bin"
BARE_PATH="/usr/bin:/bin"

run_hook() {
  jq -nc --arg c "$2" --arg d "$3" --arg s "$4" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:$s,cwd:$d,tool_input:{command:$c}}' \
    | HOME="$WORK/home" PATH="$1" "$PY" "$SCAN" --hook
}

out=$(run_hook "$STUB_PATH" "ls -la" "$REPO" s1)
assert_eq "" "$out" "non-gate command produces no output"

out=$(run_hook "$STUB_PATH" "git commit -m x" "$REPO" s1)
assert_eq 1 "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -c '1 open advisories, 1 with a fixed version')" "commit gate reports the advisory"
assert_eq 1 "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -c 'clears at 4.17.21')" "report names the clearing version"

out=$(run_hook "$STUB_PATH" "git commit -m y" "$REPO" s1)
assert_eq "" "$out" "same lockfile state reports once per session per gate"

out=$(run_hook "$STUB_PATH" "gh pr create --fill" "$REPO" s1)
assert_eq 1 "$(printf '%s' "$out" | grep -c 'merge request time')" "PR gate reports separately from the commit gate"

out=$(run_hook "$STUB_PATH" "git -C $REPO commit -m z" "$WORK/elsewhere" s2)
assert_eq 1 "$(printf '%s' "$out" | grep -c 'GHSA\|lodash')" "git -C targets the named repo, not cwd"

out=$(run_hook "$STUB_PATH" "git commit -m x" "$WORK/untracked" s3)
assert_eq "" "$out" "untracked lockfiles are not scanned"

HOME="$WORK/home" PATH="$STUB_PATH" "$PY" "$SCAN" --repo "$REPO" --no-cache > "$WORK/cli.out"
rc=$?
assert_eq 1 "$rc" "CLI exits 1 when a fixable advisory remains"
assert_eq 1 "$(grep -c 'lodash@4.17.20: 1 advisories, clears at 4.17.21' "$WORK/cli.out")" "CLI rollup line"

mkdir -p "$WORK/home/.claude/state"
jq -n --arg r "$REPO" '{ids: [], repos: {($r): ["CVE-0000-0001"]}}' > "$WORK/home/.claude/state/dep-vuln-ignore.json"
out=$(run_hook "$STUB_PATH" "git commit -m x" "$REPO" s4)
assert_eq "" "$out" "a per-repo waiver by alias silences the advisory"
rm "$WORK/home/.claude/state/dep-vuln-ignore.json"

out=$(run_hook "$BARE_PATH" "git commit -m x" "$REPO" s5)
assert_eq 1 "$(printf '%s' "$out" | jq -r '.systemMessage' | grep -c 'osv-scanner not installed')" "missing osv-scanner is reported"
out=$(run_hook "$BARE_PATH" "git commit -m y" "$REPO" s5)
assert_eq "" "$out" "missing osv-scanner is reported once per session"

exit "$ASSERT_FAILED"
