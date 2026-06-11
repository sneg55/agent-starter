#!/bin/bash
# Run every tests/*.test.sh. Exit nonzero if any file fails.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
fails=0
ran=0
for t in "$DIR"/*.test.sh; do
  [ -e "$t" ] || continue
  ran=$((ran + 1))
  echo "── $(basename "$t")"
  if bash "$t"; then
    echo "   PASS"
  else
    echo "   FAIL"
    fails=$((fails + 1))
  fi
done
echo "────────────"
if [ "$ran" -eq 0 ]; then
  echo "no test files found"; exit 1
fi
if [ "$fails" -eq 0 ]; then
  echo "All $ran test file(s) passed"
else
  echo "$fails/$ran test file(s) failed"; exit 1
fi
