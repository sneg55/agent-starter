#!/bin/bash
# Claude Code hook: codebase health check on session start
# SessionStart — reports file size distribution and flags violations
#
# Install: add to settings.json under SessionStart event

SRC_DIR="${1:-.}"

# Find code files (skip node_modules, dist, .git, etc.)
CODE_FILES=$(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) \
  ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" ! -path "*/target/*" 2>/dev/null)

if [ -z "$CODE_FILES" ]; then
  exit 0
fi

TOTAL=0
UNDER_50=0
UNDER_100=0
UNDER_200=0
UNDER_300=0
UNDER_500=0
OVER_500=0
VIOLATIONS=""

while IFS= read -r file; do
  [ -z "$file" ] && continue
  lines=$(wc -l < "$file" | tr -d ' ')
  TOTAL=$((TOTAL + 1))
  
  if [ "$lines" -le 50 ]; then
    UNDER_50=$((UNDER_50 + 1))
  elif [ "$lines" -le 100 ]; then
    UNDER_100=$((UNDER_100 + 1))
  elif [ "$lines" -le 200 ]; then
    UNDER_200=$((UNDER_200 + 1))
  elif [ "$lines" -le 300 ]; then
    UNDER_300=$((UNDER_300 + 1))
  elif [ "$lines" -le 500 ]; then
    UNDER_500=$((UNDER_500 + 1))
  else
    OVER_500=$((OVER_500 + 1))
    VIOLATIONS="$VIOLATIONS\n  ⛔ $file ($lines lines)"
  fi
  
  if [ "$lines" -gt 300 ]; then
    VIOLATIONS="$VIOLATIONS"
  fi
done <<< "$CODE_FILES"

# Calculate percentage under 200
UNDER_200_TOTAL=$((UNDER_50 + UNDER_100 + UNDER_200))
if [ "$TOTAL" -gt 0 ]; then
  PCT=$((UNDER_200_TOTAL * 100 / TOTAL))
else
  PCT=100
fi

# Only output if there are issues
if [ "$PCT" -lt 64 ] || [ -n "$VIOLATIONS" ]; then
  cat >&2 <<EOF
📊 Codebase Health Report
━━━━━━━━━━━━━━━━━━━━━━━━
Files under 200 lines: $PCT% (target: 64%)
Total code files: $TOTAL

Distribution:
  ≤50 lines:   $UNDER_50
  51-100:       $UNDER_100
  101-200:      $UNDER_200
  201-300:      $UNDER_300
  301-500:      $UNDER_500
  500+:         $OVER_500
EOF

  if [ -n "$VIOLATIONS" ]; then
    echo -e "\nFiles over 500 lines (need splitting):$VIOLATIONS" >&2
  fi
  
  if [ "$PCT" -lt 64 ]; then
    echo -e "\n⚠️ Below 64% target. Prioritize splitting large files." >&2
  fi
fi

exit 0
