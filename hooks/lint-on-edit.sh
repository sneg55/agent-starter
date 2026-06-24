#!/bin/bash
# Claude Code hook: lint + typecheck files the agent just wrote.
# PostToolUse on Write|Edit - exit 2 to block with stderr, exit 0 to pass.
#
# Philosophy: rules only shape agent behavior if the agent sees failures.
# JS/TS: runs Biome (format + fast rules, with --write), then ESLint
# (type-aware + plugin rules), then optionally tsc --noEmit. Python: runs
# ruff check --fix, then ruff format, when a ruff binary is available
# (.venv/bin/ruff or PATH).
# The agent gets structured errors back in its next turn and self-corrects.
#
# Install: copy to ~/.claude/hooks/ and add to settings.json (see README).

set -u

# Resolve the edited file path across the three invocation styles. CI passes it
# as a positional arg; Claude Code pipes the tool payload as JSON on stdin (path
# under .tool_input.file_path); legacy callers set $ARGUMENTS. Check $1 FIRST so
# the CI path never reads stdin (a blocking `cat` would hang there). Reading only
# $ARGUMENTS made this a silent no-op under Claude Code, which uses stdin.
FILE_PATH="${1:-}"
if [ -z "$FILE_PATH" ]; then
  HOOK_INPUT="${ARGUMENTS:-}"
  if [ -z "$HOOK_INPUT" ] && [ ! -t 0 ]; then
    HOOK_INPUT=$(cat 2>/dev/null)
  fi
  FILE_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // .path // empty' 2>/dev/null)
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Resolve to an absolute path. The branches below `cd` into the project root,
# after which a repo-relative path (how CI invokes this hook, e.g.
# "app/src/foo.ts") would no longer resolve and the linters would report
# "no files matching". An absolute path resolves regardless of cwd.
FILE_PATH="$(cd "$(dirname "$FILE_PATH")" && pwd)/$(basename "$FILE_PATH")"

case "$FILE_PATH" in
  *.py)
    # Python path: ruff check --fix, when a project root and ruff binary exist.
    PROJECT_ROOT=""
    DIR=$(cd "$(dirname "$FILE_PATH")" && pwd)
    while [ "$DIR" != "/" ]; do
      if [ -f "$DIR/pyproject.toml" ] || [ -f "$DIR/setup.py" ] || [ -f "$DIR/requirements.txt" ] || [ -d "$DIR/.git" ]; then
        PROJECT_ROOT="$DIR"
        break
      fi
      DIR=$(dirname "$DIR")
    done
    [ -z "$PROJECT_ROOT" ] && exit 0
    HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
    cd "$PROJECT_ROOT" || exit 0
    RUFF=""
    if [ -x .venv/bin/ruff ]; then
      RUFF=.venv/bin/ruff
    elif command -v ruff >/dev/null 2>&1; then
      RUFF=ruff
    fi
    # Ruff is best-effort: run it when present, but don't exit early if it's
    # missing - the mypy type-check below must still run for mypy-only projects.
    if [ -n "$RUFF" ]; then
      if ! RUFF_OUT=$("$RUFF" check --fix "$FILE_PATH" 2>&1); then
        printf 'Ruff errors in %s:\n%s\n' "$FILE_PATH" "$RUFF_OUT" >&2
        [ -x "$HOOK_DIR/lib/log-event.sh" ] && "$HOOK_DIR/lib/log-event.sh" lint block "$FILE_PATH" "ruff check failed"
        exit 2
      fi
      # Formatting parity with Biome's --write. Best-effort: format only fails on
      # syntax errors, which check already reported, so never block on it.
      "$RUFF" format --quiet "$FILE_PATH" >/dev/null 2>&1 || true
    fi
    # Type-check with mypy (the type-aware step, like tsc on the TS path).
    # Whole-file mypy resolves imports and can be slow, so gate it behind the
    # same opt-in marker as tsc: touch .claude/enable-typecheck-on-edit.
    if [ -f .claude/enable-typecheck-on-edit ]; then
      MYPY=""
      if [ -x .venv/bin/mypy ]; then
        MYPY=.venv/bin/mypy
      elif command -v mypy >/dev/null 2>&1; then
        MYPY=mypy
      else
        # The marker is the user's consent to type-check, so install mypy when
        # it's missing rather than silently skipping. Prefer the project venv.
        if [ -x .venv/bin/pip ]; then
          .venv/bin/pip install --quiet mypy >/dev/null 2>&1
          [ -x .venv/bin/mypy ] && MYPY=.venv/bin/mypy
        elif command -v pip3 >/dev/null 2>&1; then
          pip3 install --quiet mypy >/dev/null 2>&1 && command -v mypy >/dev/null 2>&1 && MYPY=mypy
        elif command -v pip >/dev/null 2>&1; then
          pip install --quiet mypy >/dev/null 2>&1 && command -v mypy >/dev/null 2>&1 && MYPY=mypy
        elif command -v python3 >/dev/null 2>&1; then
          python3 -m pip install --quiet mypy >/dev/null 2>&1 && command -v mypy >/dev/null 2>&1 && MYPY=mypy
        fi
        # Install can fail (no network, no pip). Warn without blocking the edit.
        [ -z "$MYPY" ] && printf 'mypy not installed and auto-install failed; skipping type-check for %s. Install mypy to enable (e.g. `pip install mypy`).\n' "$FILE_PATH" >&2
      fi
      if [ -n "$MYPY" ]; then
        if ! MYPY_OUT=$("$MYPY" "$FILE_PATH" 2>&1); then
          printf 'mypy errors in %s:\n%s\n' "$FILE_PATH" "$MYPY_OUT" >&2
          [ -x "$HOOK_DIR/lib/log-event.sh" ] && "$HOOK_DIR/lib/log-event.sh" lint block "$FILE_PATH" "mypy typecheck failed"
          exit 2
        fi
      fi
    fi
    exit 0
    ;;
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
  [ -x "$(dirname "$0")/lib/log-event.sh" ] && "$(dirname "$0")/lib/log-event.sh" lint block "$FILE_PATH" "lint or typecheck failed"
  exit 2
fi

exit 0
