#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

PROMPT="$ROOT/hooks/worktree-session-prompt.sh"
OFFER="$ROOT/hooks/worktree-exit-offer.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

MAIN="$WORK/main"
git init -q "$MAIN"
git -C "$MAIN" config user.email t@example.com
git -C "$MAIN" config user.name test
printf 'seed\n' > "$MAIN/README.md"
git -C "$MAIN" add README.md
git -C "$MAIN" commit -qm seed

context() { CLAUDE_PROJECT_DIR="$1" bash "$PROMPT" | jq -r '.hookSpecificOutput.additionalContext // ""'; }
message() { CLAUDE_PROJECT_DIR="$1" bash "$OFFER" | jq -r '.systemMessage // ""'; }

assert_eq "SHARED" "$(context "$MAIN" | grep -o 'SHARED' | head -1)" \
  "main checkout is reported as the shared checkout"
assert_eq "" "$(context "$WORK" 2>/dev/null)" "a non-repo directory emits nothing"

LINKED="$WORK/feature"
git -C "$MAIN" worktree add -q -b feature "$LINKED"
assert_eq "Worktree" "$(context "$LINKED" | awk '{print $1}')" \
  "a linked worktree is reported as a worktree"
assert_eq "" "$(context "$LINKED" | grep -o 'SHARED')" \
  "a linked worktree is not called the shared checkout"

assert_eq "" "$(message "$MAIN")" "no exit offer in the main checkout"
assert_eq "" "$(message "$LINKED")" "no exit offer without an upstream"

printf 'work\n' > "$LINKED/feature.txt"
git -C "$LINKED" add feature.txt
git -C "$LINKED" commit -qm work
BARE="$WORK/origin.git"
git init -q --bare "$BARE"
git -C "$LINKED" remote add origin "$BARE"
git -C "$LINKED" push -q -u origin feature
assert_eq "Worktree" "$(message "$LINKED" | awk '{print $1}')" \
  "clean and fully pushed worktree gets the exit offer"

assert_eq "" "$(context "$MAIN" | grep -o 'origin/main')" \
  "the base branch is not hardcoded to origin/main"
assert_eq "default" "$(context "$MAIN" | grep -o "repo's default branch" | awk '{print $2}')" \
  "with no origin HEAD the suggestion stays branch-agnostic"

printf 'dirty\n' > "$LINKED/scratch.txt"
assert_eq "" "$(message "$LINKED")" "a dirty worktree gets no exit offer"
rm -f "$LINKED/scratch.txt"

printf 'more\n' >> "$LINKED/feature.txt"
git -C "$LINKED" commit -qam more
assert_eq "" "$(message "$LINKED")" "an unpushed commit blocks the exit offer"

git -C "$MAIN" worktree remove --force "$LINKED"
exit $ASSERT_FAILED
