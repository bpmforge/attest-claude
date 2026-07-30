#!/usr/bin/env bash
#
# ci-check.sh — static self-check for the attest-claude distribution repo.
#
# This repo has no npm test / build step of its own (agents/skills/scripts
# are either GENERATED from attest or per-target content —
# see GENERATED_FILES.txt). What CAN regress here without any framework
# catching it: a broken shell script, a broken mjs script, or a
# GENERATED_FILES.txt entry pointing at a file that no longer exists.
# This script catches all three. Exit 0 = clean, 1 = failures found.

set -u
cd "$(dirname "$0")/.."

FAIL=0

echo "== bash -n syntax check =="
while IFS= read -r -d '' f; do
  if ! bash -n "$f" 2>/tmp/ci-check-err; then
    echo "FAIL: $f"
    cat /tmp/ci-check-err
    FAIL=1
  fi
done < <(find . -name "*.sh" -not -path "./node_modules/*" -print0)

echo "== node --check syntax check =="
while IFS= read -r -d '' f; do
  if ! node --check "$f" 2>/tmp/ci-check-err; then
    echo "FAIL: $f"
    cat /tmp/ci-check-err
    FAIL=1
  fi
done < <(find . -name "*.mjs" -not -path "./node_modules/*" -print0)

echo "== GENERATED_FILES.txt completeness =="
if [ -f GENERATED_FILES.txt ]; then
  while IFS= read -r line; do
    case "$line" in
      \#*|"") continue ;;
    esac
    if [ ! -f "$line" ]; then
      echo "FAIL: GENERATED_FILES.txt lists '$line' but it does not exist on disk"
      FAIL=1
    fi
  done < GENERATED_FILES.txt
else
  echo "FAIL: GENERATED_FILES.txt missing"
  FAIL=1
fi

rm -f /tmp/ci-check-err

if [ "$FAIL" -eq 0 ]; then
  echo "ci-check: PASS"
  exit 0
else
  echo "ci-check: FAIL"
  exit 1
fi
