#!/usr/bin/env bash
# UserPromptSubmit hook: when the user runs /loop or /goal, inject an instruction
# telling Claude to first propose improved, drop-in replacements for the command
# and let the user pick one interactively via AskUserQuestion (no copy-paste),
# then run only the chosen command.
#
# The hook itself does no LLM work and spawns no nested session - it only injects
# context, so the already-running model generates the variants. That keeps it
# fast (<50ms), needs no API key, and no matcher (UserPromptSubmit has none), so
# it filters to /loop and /goal by prompt text. Non-blocking: every other prompt,
# and any parse failure, passes through untouched (exit 0).
set -euo pipefail

input="$(cat)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // empty')"

# Only act on /loop and /goal invocations; everything else passes through.
case "$prompt" in
  /loop*|/goal*) ;;
  *) exit 0 ;;
esac

cat <<EOF
<loop-goal-review>
The user is about to run this command: $prompt

Before executing it, do this first:
1. Generate 2-3 improved, drop-in replacements for the command. Keep each faithful
   to the original intent (preserve the interval and args); only add the missing
   precision - explicit success criteria, an explicit stop condition, bounded
   scope, and a verification step.
2. Call the AskUserQuestion tool (header "Improve loop?") with:
     - one option per replacement, lettered in order: label "A - <short label>",
       "B - <short label>", ... and put the full rewritten command plus a one-line
       "Why:" in each option's description.
     - a final option: label "Run original unchanged", description = the original command.
3. Run ONLY the command the user selects, verbatim. For the last option, run the
   original command as-is.

If the command already has clear success criteria, a stop condition, bounded scope,
and a verification step, skip the question and run it unchanged. If you cannot show
an interactive prompt (headless/non-interactive session), run the original unchanged.
</loop-goal-review>
EOF
exit 0
