#!/usr/bin/env bash
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ "$GIT_DIR" = "$COMMON_DIR" ] && exit 0

[ -z "$(git status --porcelain 2>/dev/null)" ] || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ "$BRANCH" = "HEAD" ] && exit 0

UPSTREAM=$(git rev-parse --abbrev-ref "$BRANCH@{upstream}" 2>/dev/null) || exit 0
[ "$(git rev-list --count "$UPSTREAM..$BRANCH" 2>/dev/null || echo 1)" = "0" ] || exit 0

jq -nc --arg m "Worktree '$BRANCH' is clean and fully pushed to $UPSTREAM. Nothing would be lost by exiting it now." \
  '{systemMessage:$m}'
