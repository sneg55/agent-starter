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

LIB="$(dirname "$0")/lib"
. "$LIB/hook-input.sh"
. "$LIB/redact.sh"

hook_input_init "${1:-}"
CMD=$(hook_input_command)
# No command in the payload means there is nothing to police. That is not a
# malformed event (hook_input_init already rejected those, loudly); it is an
# event shape this hook does not apply to.
[ -z "$CMD" ] && exit 0

check() { echo "$CMD" | grep -qE "$1"; }

# REASON is prose for the agent; CODE is the stable machine-readable token that
# goes to the ledger. /reflect should branch on the code, not match the prose,
# so wording can be improved without invalidating past events.
REASON=""
CODE=""
if check 'git[[:space:]]+push[[:space:]]+[^|;&]*--force([[:space:]]|$)'; then
  CODE="force_push"
  REASON="'git push --force' rewrites remote history - use --force-with-lease"
elif check 'git[[:space:]]+push[[:space:]]+([^|;&]*[[:space:]])?-f([[:space:]]|$)'; then
  CODE="force_push"
  REASON="'git push -f' rewrites remote history - use --force-with-lease"
elif check 'git[[:space:]]+reset[[:space:]]+[^|;&]*--(hard|merge)'; then
  CODE="destructive_reset"
  REASON="'git reset --hard/--merge' destroys uncommitted work - stash first, or restore specific paths"
elif check 'git[[:space:]]+clean[[:space:]]+[^|;&]*-[A-Za-z]*f'; then
  CODE="untracked_delete"
  REASON="'git clean -f' permanently deletes untracked files"
elif check 'git[[:space:]]+checkout[[:space:]]+--[[:space:]]+\.([[:space:]]|$)'; then
  CODE="worktree_discard"
  REASON="'git checkout -- .' discards every uncommitted change in the working tree"
elif check 'git[[:space:]]+restore[[:space:]]+\.([[:space:]]|$)'; then
  CODE="worktree_discard"
  REASON="'git restore .' discards every uncommitted change in the working tree"
elif check 'rm[[:space:]]+(-[A-Za-z]+[[:space:]]+)+(/|/\*|~|~/|\$HOME|\$HOME/)([[:space:]]|$)'; then
  CODE="dangerous_recursive_delete"
  REASON="recursive rm on /, ~ or \$HOME is unrecoverable"
elif check 'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/([[:space:]]|$)'; then
  CODE="permission_destruction"
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
  # Ledger gets the reason code plus the command's SHAPE, never the command.
  # The blocked command is the one most likely to be carrying a token, a signed
  # URL, or customer data, and the ledger is durable on-disk state.
  [ -x "$LIB/log-event.sh" ] && "$LIB/log-event.sh" dangerous-command block "" "$CODE: $(redact_command "$CMD")"
  exit 2
fi

exit 0
