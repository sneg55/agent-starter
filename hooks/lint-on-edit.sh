#!/bin/bash
# Claude Code hook: lint + typecheck files the agent just wrote.
# PostToolUse on Write|Edit — exit 2 to block with stderr, exit 0 to pass.
#
# Philosophy: rules only shape agent behavior if the agent sees failures.
# This hook runs Biome (format + fast rules, with --write), then ESLint
# (type-aware + plugin rules), then optionally tsc --noEmit. The agent
# gets structured errors back in its next turn and self-corrects.
#
# Install: copy to ~/.claude/hooks/ and add to settings.json (see README).

set -u

FILE_PATH=$(echo "${ARGUMENTS:-}" | jq -r '.file_path // .path // empty' 2>/dev/null)
if [ -z "$FILE_PATH" ]; then
  FILE_PATH="${1:-}"
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac

# Walk up to find the project root (nearest package.json).
PROJECT_ROOT=""
DIR=$(cd "$(dirname "$FILE_PATH")" && pwd)
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/package.json" ]; then
    PROJECT_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

cd "$PROJECT_ROOT" || exit 0

HAS_ESLINT_CONFIG=0
for cfg in eslint.config.mjs eslint.config.js eslint.config.cjs .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yaml .eslintrc.yml; do
  if [ -f "$cfg" ]; then HAS_ESLINT_CONFIG=1; break; fi
done

HAS_BIOME_CONFIG=0
for cfg in biome.json biome.jsonc; do
  if [ -f "$cfg" ]; then HAS_BIOME_CONFIG=1; break; fi
done

HAS_TSCONFIG=0
[ -f tsconfig.json ] && HAS_TSCONFIG=1

FAIL=0
OUT=""

# Biome first: fast, autofixes formatting + syntactic rules.
if [ "$HAS_BIOME_CONFIG" -eq 1 ] && [ -x node_modules/.bin/biome ]; then
  if ! BIOME_OUT=$(node_modules/.bin/biome check --write --no-errors-on-unmatched "$FILE_PATH" 2>&1); then
    OUT="${OUT}Biome errors in ${FILE_PATH}:
${BIOME_OUT}
"
    FAIL=1
  fi
fi

# ESLint second: type-aware + plugin rules (import resolution, sonarjs, security).
if [ "$HAS_ESLINT_CONFIG" -eq 1 ] && [ -x node_modules/.bin/eslint ]; then
  if ! LINT_OUT=$(node_modules/.bin/eslint --fix --cache --cache-location node_modules/.cache/eslint/ --max-warnings 0 "$FILE_PATH" 2>&1); then
    OUT="${OUT}ESLint errors in ${FILE_PATH}:
${LINT_OUT}
"
    FAIL=1
  fi
fi

# Type-check only when the file is TS and tsconfig exists. --noEmit is whole-project,
# which is slow on huge repos; gate behind a marker file to opt in per project.
if [ "$HAS_TSCONFIG" -eq 1 ] && [ -f .claude/enable-typecheck-on-edit ]; then
  case "$FILE_PATH" in
    *.ts|*.tsx)
      if [ -x node_modules/.bin/tsc ]; then
        if ! TSC_OUT=$(node_modules/.bin/tsc --noEmit 2>&1); then
          OUT="${OUT}TypeScript errors:
${TSC_OUT}
"
          FAIL=1
        fi
      fi
      ;;
  esac
fi

if [ "$FAIL" -eq 1 ]; then
  printf '%s' "$OUT" >&2
  exit 2
fi

exit 0
