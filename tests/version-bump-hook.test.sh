#!/bin/bash
# Tests for hooks/check-version-bump.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
HOOK="$ROOT/hooks/check-version-bump.sh"

# Build a throwaway repo that versions like agent-starter, with a `main`
# baseline and a feature branch we can mutate per case.
setup_repo() {
  tmp=$(mktemp -d)
  git -C "$tmp" init -q
  git -C "$tmp" config user.email t@t.t
  git -C "$tmp" config user.name t
  git -C "$tmp" checkout -q -b main
  mkdir -p "$tmp/.claude-plugin" "$tmp/skills" "$tmp/docs"
  printf '0.1.0\n' > "$tmp/VERSION"
  echo '{}' > "$tmp/.claude-plugin/plugin.json"
  echo 'base' > "$tmp/skills/a.md"
  echo 'base' > "$tmp/docs/a.md"
  git -C "$tmp" add -A
  git -C "$tmp" commit -qm init
  git -C "$tmp" checkout -q -b feature
  echo "$tmp"
}

# Run the hook from inside the repo with a git push command.
run_in() {
  (cd "$1" && ARGUMENTS='{"command":"git push -u origin HEAD"}' bash "$HOOK" 2>/dev/null)
}

# (a) release-relevant change, no VERSION bump -> blocked
r=$(setup_repo); echo change >> "$r/skills/a.md"; git -C "$r" commit -qam edit
run_in "$r"; assert_eq 2 $? "blocks release change without bump"
rm -rf "$r"

# (b) release-relevant change WITH VERSION bump -> allowed
r=$(setup_repo); echo change >> "$r/skills/a.md"; printf '0.1.1\n' > "$r/VERSION"
git -C "$r" commit -qam "edit + bump"
run_in "$r"; assert_eq 0 $? "allows release change with bump"
rm -rf "$r"

# (c) docs-only change, no bump -> allowed
r=$(setup_repo); echo change >> "$r/docs/a.md"; git -C "$r" commit -qam "docs"
run_in "$r"; assert_eq 0 $? "allows docs-only change without bump"
rm -rf "$r"

# (d) escape hatch -> allowed even with release change, no bump
r=$(setup_repo); echo change >> "$r/skills/a.md"; git -C "$r" commit -qam edit
(cd "$r" && CLAUDE_ALLOW_NO_BUMP=1 ARGUMENTS='{"command":"git push"}' bash "$HOOK" 2>/dev/null)
assert_eq 0 $? "CLAUDE_ALLOW_NO_BUMP=1 disables the hook"
rm -rf "$r"

# (e) non-push command -> allowed regardless of state
r=$(setup_repo); echo change >> "$r/skills/a.md"; git -C "$r" commit -qam edit
(cd "$r" && ARGUMENTS='{"command":"git status"}' bash "$HOOK" 2>/dev/null)
assert_eq 0 $? "ignores non-push commands"
rm -rf "$r"

# (f) self-gate: repo without VERSION/.claude-plugin -> allowed
tmp=$(mktemp -d); git -C "$tmp" init -q
git -C "$tmp" config user.email t@t.t; git -C "$tmp" config user.name t
mkdir -p "$tmp/skills"; echo x > "$tmp/skills/a.md"
git -C "$tmp" add -A; git -C "$tmp" commit -qm init
git -C "$tmp" checkout -q -b feature; echo y >> "$tmp/skills/a.md"; git -C "$tmp" commit -qam edit
run_in "$tmp"; assert_eq 0 $? "no-op when repo is not a versioned plugin"
rm -rf "$tmp"

# (g) logs a version-bump event when it blocks
r=$(setup_repo); echo change >> "$r/skills/a.md"; git -C "$r" commit -qam edit
run_in "$r"
rule=$(jq -r '.rule' "$r/.harness/ledger.jsonl" 2>/dev/null | head -1)
assert_eq version-bump "$rule" "logs rule=version-bump"
rm -rf "$r"

exit $ASSERT_FAILED
