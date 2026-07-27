#!/bin/bash
# Claude Code hook: enforce file size limits
# PostToolUse on Write|Edit - exit 2 to block, exit 0 to pass
# (wire to both: files can grow past the limit through repeated Edits)
#
# Install: copy to ~/.claude/hooks/ and add to settings.json
# The hook receives the tool payload as JSON on stdin

. "$(dirname "$0")/lib/hook-input.sh"
hook_input_init "${1:-}"
FILE_PATH=$(hook_input_file)

# Skip if we can't determine the file
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Skip non-code files. .mdx and .markdown belong here with .md: they are prose,
# and a long article is a long article, not a module that wants extracting into
# types.ts. The split advice below cannot apply to any of them.
case "$FILE_PATH" in
  *.md|*.mdx|*.markdown|*.json|*.yaml|*.yml|*.toml|*.lock|*.svg|*.png|*.jpg|*.csv|*.txt)
    exit 0
    ;;
esac

LINE_COUNT=$(wc -l < "$FILE_PATH" | tr -d ' ')

# Stylesheets are not modules. They hold no types, constants, or helper functions to
# extract, so the module advice below is noise for them, and 200 lines is tight for a
# language whose unit is one declaration per line. They split by layer instead, and
# they get their own, looser thresholds.
case "$FILE_PATH" in
  *.css|*.scss|*.sass|*.less)
    WARN_THRESHOLD=250
    BLOCK_THRESHOLD=400
    SPLIT_ADVICE="Split by layer - extract into separate stylesheets, imported in order:
- tokens.css - custom properties only (color, space, type, elevation)
- base.css - reset, document rhythm, app shell
- components.css - one block per component
- states.css - empty / error / loading states and their keyframes

Keep each layer under the warn threshold. Do NOT split in the middle of a component."
    ;;
  *.daml)
    WARN_THRESHOLD=300
    BLOCK_THRESHOLD=450
    SPLIT_ADVICE="Split by contract concern - extract into separate modules:
- Types.daml - shared data types, enums, and type aliases
- One module per template family - keep a template with its own choices, never apart
- Test suites: one module per lifecycle path (happy, edge case, multi-party)

Keep a template and its choices together. Do NOT split a template from its choices to
get under a line count."
    ;;
  *.astro)
    # An .astro file is a component, its scoped stylesheet, and its client script in one
    # file - that colocation is the framework's unit, not a smell. A real example: a 301
    # line Header.astro was 21 frontmatter, 31 markup, 149 scoped <style>, 100 client
    # <script>. Scored against the module default it is the CSS that trips the limit, and
    # the module advice below has nothing to act on. Flattening the <style> into a global
    # sheet to win back lines would lose the scoping and make the code worse.
    WARN_THRESHOLD=250
    BLOCK_THRESHOLD=400
    SPLIT_ADVICE="Split by concern, keeping the Astro unit intact:
- extract a child .astro component (with its own scoped <style>) for a distinct region
- move a long client <script> into src/scripts/*.ts and import it
- lift genuinely shared rules into src/styles/*.css; keep component-scoped CSS in place
- move data arrays and helpers into src/lib/*.ts

Do NOT flatten scoped <style> into a global stylesheet to win back lines."
    ;;
  *)
    WARN_THRESHOLD=200
    BLOCK_THRESHOLD=300
    SPLIT_ADVICE="Split by concern - extract into separate files:
- types.ts / types.py - type definitions and interfaces
- constants.ts / constants.py - named constants and config values
- validation.ts / validation.py - input validation logic
- utils.ts / utils.py - pure helper functions
- [Name].test.ts - tests (always separate)

Each extracted file should handle a single responsibility.
Do NOT just move code around - ensure clean imports and no circular dependencies."
    ;;
esac

# A project may set its own thresholds, because the right number depends on the
# codebase and not on this file. Read last so it wins over the per-extension
# defaults above.
#
# The root comes from the edited file rather than from $PWD, the same way
# lib/log-event.sh finds where to put the ledger, so the config sits next to the
# ledger by construction and is found whatever directory the session runs from.
#
# Only the two numbers are read, by pattern, not by sourcing the file: a config
# in the repo would otherwise be arbitrary shell running on every edit. And
# SPLIT_ADVICE stays the hook's, so a project can move the line but cannot turn
# the advice into something unhelpful.
# No repo means no project, so no project config: falling back to $PWD here
# would hand a file edited outside any repo the thresholds of whatever project
# the shell happened to be sitting in.
CONF_DIR=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
CONF="${CONF_DIR}/.harness/file-size.conf"
if [ -n "$CONF_DIR" ] && [ -f "$CONF" ]; then
  PROJECT_WARN=$(sed -n 's/^WARN_THRESHOLD=\([0-9][0-9]*\).*/\1/p' "$CONF" | tail -1)
  PROJECT_BLOCK=$(sed -n 's/^BLOCK_THRESHOLD=\([0-9][0-9]*\).*/\1/p' "$CONF" | tail -1)
  [ -n "$PROJECT_WARN" ] && WARN_THRESHOLD="$PROJECT_WARN"
  [ -n "$PROJECT_BLOCK" ] && BLOCK_THRESHOLD="$PROJECT_BLOCK"
fi

if [ "$LINE_COUNT" -gt "$BLOCK_THRESHOLD" ]; then
  cat >&2 <<EOF
⛔ FILE TOO LARGE: $FILE_PATH has $LINE_COUNT lines (limit: $BLOCK_THRESHOLD)

This file exceeds the maximum size. You MUST split it before proceeding.

$SPLIT_ADVICE
EOF
  [ -x "$(dirname "$0")/lib/log-event.sh" ] && "$(dirname "$0")/lib/log-event.sh" file-size block "$FILE_PATH" "$LINE_COUNT lines (limit $BLOCK_THRESHOLD)"
  exit 2

elif [ "$LINE_COUNT" -gt "$WARN_THRESHOLD" ]; then
  cat >&2 <<EOF
⚠️ FILE GETTING LARGE: $FILE_PATH has $LINE_COUNT lines (target: <$WARN_THRESHOLD)

Consider splitting soon.

$SPLIT_ADVICE
EOF
  [ -x "$(dirname "$0")/lib/log-event.sh" ] && "$(dirname "$0")/lib/log-event.sh" file-size warn "$FILE_PATH" "$LINE_COUNT lines (target <$WARN_THRESHOLD)"
  exit 0
fi

exit 0
