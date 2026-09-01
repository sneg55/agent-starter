#!/bin/bash
# Guards that the self-improvement loop is wired into the bootstrap docs.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"

check() { # file pattern message
  if grep -q "$2" "$ROOT/$1"; then return 0; fi
  ASSERT_FAILED=1; echo "  MISSING in $1: $2"
}

check AGENT.md ".harness" "AGENT.md creates .harness"
check AGENT.md "reflect" "AGENT.md installs reflect skill"
check AGENT.md "log-event.sh" "AGENT.md installs hook lib"
check "skills/new-project/SKILL.md" ".harness" "new-project creates .harness"
check "skills/new-project/SKILL.md" "reflect" "new-project installs reflect skill"
check "templates/CLAUDE.md" "Self-improvement loop" "CLAUDE template documents the loop"
check "templates/CLAUDE.md" ".harness/ledger.jsonl" "CLAUDE template names the ledger"

check "hooks/README.md" "Self-improvement ledger" "README documents the ledger section"
check "hooks/README.md" "log-event.sh" "README documents the log-event helper"

check AGENT.md "install.sh" "AGENT.md uses the installer"
check "skills/new-project/SKILL.md" "install.sh" "new-project uses the installer"
check "hooks/README.md" "install.sh" "hooks README documents the installer"
check "hooks/README.md" "block-dangerous-commands" "hooks README documents the dangerous-commands hook"

check "hooks/README.md" "rm-scope-guard" "hooks README documents the rm scope guard"
check "hooks/README.md" "worktree-exit-offer" "hooks README documents the worktree pair"
check "hooks/README.md" "check-new-comments" "hooks README documents the comment guard"
check "hooks/README.md" "check-em-dash" "hooks README documents the em-dash guard"
check "hooks/README.md" "file-size.conf" "hooks README documents per-project size thresholds"
check README.md "rm-scope-guard" "README lists the rm scope guard"
check README.md "with-comment-guard" "README names the comment-guard flag"
check install.sh "with-em-dash-guard" "installer offers the em-dash flag"
check "hooks/hooks.json" "worktree-exit-offer" "plugin wires the Stop hook"
check "hooks/hooks.json" "rm-scope-guard" "plugin wires the rm scope guard"
check "templates/CLAUDE.md" "Verify a problem before reporting it" "CLAUDE template carries the verify rule"
check "templates/CLAUDE.md" "Dispatching subagents" "CLAUDE template carries the subagent rules"
check "templates/CLAUDE.md" "One worker per worktree" "CLAUDE template carries the worktree rule"
check "templates/CLAUDE.md" "Never commit internal documents" "CLAUDE template carries the public-repo rule"
check "templates/CLAUDE.md" "blocked by a classifier" "CLAUDE template carries the classifier rule"

exit $ASSERT_FAILED
