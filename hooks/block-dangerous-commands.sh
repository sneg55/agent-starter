#!/bin/bash
# Claude Code hook: block destructive shell commands before they run.
# PreToolUse on Bash - exit 2 blocks with stderr, exit 0 allows.
#
# Blocks:
#   - git push --force / -f            (use --force-with-lease instead)
#   - git reset --hard / --merge
#   - git clean -f...
#   - git checkout -- . / git restore . (discards all uncommitted work)
#   - recursive rm on /, /*, ~ or $HOME
#   - chmod -R 777 /
#
# Escape hatch: CLAUDE_ALLOW_DANGEROUS=1 disables the hook.
#
# Install: copy to ~/.claude/hooks/, chmod +x, wire in settings.json (see README),
# or run install.sh from the repo root.

set -u

[ "${CLAUDE_ALLOW_DANGEROUS:-0}" = "1" ] && exit 0

CMD=$(echo "${ARGUMENTS:-}" | jq -r '.command // empty' 2>/dev/null)
[ -z "$CMD" ] && CMD="${1:-}"
[ -z "$CMD" ] && exit 0

check() { echo "$CMD" | grep -qE "$1"; }

REASON=""
if check 'git[[:space:]]+push[[:space:]]+[^|;&]*--force([[:space:]]|$)'; then
  REASON="'git push --force' rewrites remote history - use --force-with-lease"
elif check 'git[[:space:]]+push[[:space:]]+([^|;&]*[[:space:]])?-f([[:space:]]|$)'; then
  REASON="'git push -f' rewrites remote history - use --force-with-lease"
elif check 'git[[:space:]]+reset[[:space:]]+[^|;&]*--(hard|merge)'; then
  REASON="'git reset --hard/--merge' destroys uncommitted work - stash first, or restore specific paths"
elif check 'git[[:space:]]+clean[[:space:]]+[^|;&]*-[A-Za-z]*f'; then
  REASON="'git clean -f' permanently deletes untracked files"
elif check 'git[[:space:]]+checkout[[:space:]]+--[[:space:]]+\.([[:space:]]|$)'; then
  REASON="'git checkout -- .' discards every uncommitted change in the working tree"
elif check 'git[[:space:]]+restore[[:space:]]+\.([[:space:]]|$)'; then
  REASON="'git restore .' discards every uncommitted change in the working tree"
elif check 'rm[[:space:]]+(-[A-Za-z]+[[:space:]]+)+(/|/\*|~|~/|\$HOME|\$HOME/)([[:space:]]|$)'; then
  REASON="recursive rm on /, ~ or \$HOME is unrecoverable"
elif check 'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/([[:space:]]|$)'; then
  REASON="'chmod -R 777 /' destroys system permissions"
fi

if [ -n "$REASON" ]; then
  cat >&2 <<EOF
Blocked dangerous command:
  $CMD

Why: $REASON.

If this is genuinely intended, ask the developer to run it themselves, or
re-run with CLAUDE_ALLOW_DANGEROUS=1 after they approve.
EOF
  [ -x "$(dirname "$0")/lib/log-event.sh" ] && "$(dirname "$0")/lib/log-event.sh" dangerous-command block "" "$CMD"
  exit 2
fi

exit 0
