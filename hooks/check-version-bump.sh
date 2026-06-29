#!/bin/bash
# Claude Code hook: require a version bump before pushing release-relevant changes.
# PreToolUse on Bash - exit 2 blocks with stderr, exit 0 allows.
#
# Fires only on `git push`. Diffs the current branch against main: if any
# release-relevant file changed across the branch but VERSION did not, the push
# is blocked. A pure bump (VERSION changed) or a docs/tests-only change passes.
# This encourages each PR to carry its own version bump (see AGENT.md).
#
# Self-gating: no-op unless the repo has a VERSION file and a .claude-plugin/
# directory, so it is harmless in projects that do not version this way.
#
# Escape hatch: CLAUDE_ALLOW_NO_BUMP=1 disables the hook.
#
# Install: wired project-locally via .claude/settings.json (not install.sh),
# so it only enforces in this repo.

set -u

[ "${CLAUDE_ALLOW_NO_BUMP:-0}" = "1" ] && exit 0

CMD=$(echo "${ARGUMENTS:-}" | jq -r '.command // empty' 2>/dev/null)
[ -z "$CMD" ] && CMD="${1:-}"
[ -z "$CMD" ] && exit 0

# Only act on git push.
echo "$CMD" | grep -qE 'git[[:space:]]+push([[:space:]]|$)' || exit 0

# Must be inside a git repo that versions like agent-starter.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$ROOT/VERSION" ] && [ -d "$ROOT/.claude-plugin" ] || exit 0

# Baseline to diff against: prefer the remote tip of main, then local main.
BASE=""
if git -C "$ROOT" rev-parse --verify --quiet origin/main >/dev/null; then
  BASE=origin/main
elif git -C "$ROOT" rev-parse --verify --quiet main >/dev/null; then
  BASE=main
fi
[ -z "$BASE" ] && exit 0

CHANGED=$(git -C "$ROOT" diff --name-only "$BASE...HEAD" 2>/dev/null)
[ -z "$CHANGED" ] && exit 0

# Files whose change warrants a release (everything else - tests, docs, README,
# LICENSE, .gitignore, .harness, VERSION itself - never requires a bump).
RELEVANT=$(echo "$CHANGED" | grep -E '^(skills/|hooks/|templates/|guides/|install\.sh|AGENT\.md|ADOPT\.md|\.claude-plugin/)')
[ -z "$RELEVANT" ] && exit 0

# Release-relevant files changed - did VERSION change too?
echo "$CHANGED" | grep -qx 'VERSION' && exit 0

cat >&2 <<EOF
Blocked push: release-relevant files changed without a version bump.

Changed since $BASE:
$(echo "$RELEVANT" | sed 's/^/  - /')

VERSION is still $(cat "$ROOT/VERSION" 2>/dev/null). Bump VERSION (and the two
.claude-plugin manifests to match), commit, then push again.

If this push genuinely needs no release, re-run with CLAUDE_ALLOW_NO_BUMP=1.
EOF
[ -x "$(dirname "$0")/lib/log-event.sh" ] && "$(dirname "$0")/lib/log-event.sh" version-bump block "" "$CMD"
exit 2
