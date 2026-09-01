#!/usr/bin/env bash
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo DETACHED)
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) \
  || BASE=$(git rev-parse --abbrev-ref "$BRANCH@{upstream}" 2>/dev/null) \
  || BASE=""
if [ -n "$BASE" ]; then
  FROM="branched from $BASE"
else
  FROM="branched from this repo's default branch"
fi

if [ "$GIT_DIR" != "$COMMON_DIR" ]; then
  CONTEXT="Worktree session: $PWD on branch '$BRANCH' ($DIRTY uncommitted files). Verify changes here, not in the main checkout."
else
  CONTEXT="This is the SHARED MAIN CHECKOUT of this repo, on branch '$BRANCH' ($DIRTY uncommitted files), not a worktree. Other sessions and agents use this same checkout, so a branch flip here can silently revert edits. BEFORE making any edit, ASK the user whether to take a fresh worktree $FROM. If the user declines, continue here without asking again."
fi

jq -nc --arg c "$CONTEXT" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
