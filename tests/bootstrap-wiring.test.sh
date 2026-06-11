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

exit $ASSERT_FAILED
