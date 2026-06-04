#!/bin/bash
# Claude Code hook: block writes that introduce silent error handling.
# PostToolUse on Write|Edit — exit 2 to block with stderr, exit 0 to pass.
#
# Catches: bare `except:`, `except: pass`, `except: ...`, empty `catch {}`,
# and `catch` blocks whose only body is console.log (swallows errors with
# a low-severity log).
#
# Rationale: LLMs routinely wrap code in try/except to make a test go green.
# The code still breaks in prod — just silently. Every handler must either
# re-raise, return a sentinel, or log with context via console.error/warn.
#
# Exempt a single site with an inline comment:
#   Python: `# silent-ok`
#   JS/TS:  `// silent-ok`
#
# Install: copy to ~/.claude/hooks/, chmod +x, wire in settings.json (see README).

set -u

FILE_PATH=$(echo "${ARGUMENTS:-}" | jq -r '.file_path // .path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && FILE_PATH="${1:-}"
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

VIOLATIONS=""

case "$FILE_PATH" in
  *.py)
    # Bare `except:` (no type). Portable ERE — BSD grep has no -P (PCRE).
    if grep -nE '^[[:space:]]*except[[:space:]]*:' "$FILE_PATH" | grep -v 'silent-ok' > /tmp/silerr.$$ 2>/dev/null && [ -s /tmp/silerr.$$ ]; then
      VIOLATIONS="${VIOLATIONS}  Bare except:
$(cat /tmp/silerr.$$)
"
    fi
    # except/pass, except/continue, except/... — heuristic two-line scan.
    # POSIX classes only — BSD/one-true awk doesn't grok \s or \b.
    # Exempt via '# silent-ok' on either the except or the body line.
    if awk '
      /^[[:space:]]*except([[:space:]]|:|$)/ { e=NR; eline=$0; next }
      e && NR==e+1 && /^[[:space:]]*(pass|continue|\.\.\.)[[:space:]]*$/ {
        if (eline !~ /silent-ok/ && $0 !~ /silent-ok/) { print e":"eline; print NR":"$0 }
        e=0; next
      }
      { e=0 }
    ' "$FILE_PATH" > /tmp/silerr.$$ 2>/dev/null && [ -s /tmp/silerr.$$ ]; then
      VIOLATIONS="${VIOLATIONS}  except/pass or except/continue or except/...:
$(cat /tmp/silerr.$$)
"
    fi
    rm -f /tmp/silerr.$$
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    # Empty catch block: catch {} or catch (e) {}. Portable ERE — no -P on BSD grep.
    if grep -nE 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}' "$FILE_PATH" | grep -v 'silent-ok' > /tmp/silerr.$$ 2>/dev/null && [ -s /tmp/silerr.$$ ]; then
      VIOLATIONS="${VIOLATIONS}  Empty catch block:
$(cat /tmp/silerr.$$)
"
    fi
    # catch block whose next non-empty line is only console.log(...)
    # POSIX classes only — BSD/one-true awk doesn't grok \s or \S.
    # Exempt via '// silent-ok' on either the catch or the console.log line.
    if awk '
      /catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{/ { c=NR; cline=$0; next }
      c && /^[[:space:]]*console\.log\(/ {
        if (cline !~ /silent-ok/ && $0 !~ /silent-ok/) { print c":"cline; print NR":"$0 }
        c=0; next
      }
      c && /^[[:space:]]*[^[:space:]]/ { c=0 }
    ' "$FILE_PATH" > /tmp/silerr.$$ 2>/dev/null && [ -s /tmp/silerr.$$ ]; then
      VIOLATIONS="${VIOLATIONS}  catch with only console.log (use console.error):
$(cat /tmp/silerr.$$)
"
    fi
    rm -f /tmp/silerr.$$
    ;;
  *)
    exit 0 ;;
esac

if [ -n "$VIOLATIONS" ]; then
  cat >&2 <<EOF
Blocked: silent error handling in ${FILE_PATH}:
${VIOLATIONS}
Fix: log with context via console.error/logger, then re-raise or return a
sentinel. Exempt a single site with '// silent-ok' (JS/TS) or '# silent-ok' (Py).

See guides/hooks-reference.md § "Block silent error patterns".
EOF
  exit 2
fi

exit 0
