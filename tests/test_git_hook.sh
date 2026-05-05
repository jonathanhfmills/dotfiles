#!/usr/bin/env bash
# Cycle 6 RED→GREEN: on_issue.sh triggers debate and writes record
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[test_git_hook] Simulating new issue event..."

SLUG="hook-test-$$"
bash "$REPO_ROOT/scripts/on_issue.sh" \
  "https://github.com/example/repo/issues/99" \
  "Should we use tabs or spaces for indentation?" \
  "$SLUG"

RECORD=$(ls -t "$REPO_ROOT/debates"/*.md 2>/dev/null | head -1)
[[ -n "$RECORD" ]] || { echo "FAIL: no debate record found after on_issue.sh"; exit 1; }

grep -q "issue_slug:" "$RECORD" || { echo "FAIL: issue_slug missing from record"; exit 1; }

echo "PASS: git hook trigger produces debate record"
