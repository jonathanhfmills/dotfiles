#!/usr/bin/env bash
# Makefile delegation targets exist and help text shows them
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[test_make_targets] Checking Makefile targets..."

for target in debate maintainer observer ralph escalate training-pr hindsight digital-twin agent-start test; do
  grep -q "^${target}[: ]" "$REPO_ROOT/Makefile" || { echo "FAIL: target '$target' not in Makefile"; exit 1; }
done

HELP_OUT=$(make -C "$REPO_ROOT" help 2>/dev/null || true)
echo "$HELP_OUT" | grep -q "debate" || { echo "FAIL: 'debate' missing from make help"; exit 1; }
echo "$HELP_OUT" | grep -q "maintainer" || { echo "FAIL: 'maintainer' missing from make help"; exit 1; }

# Delegation targets invoke bicameral-mind
grep -q "bicameral-mind" "$REPO_ROOT/Makefile" || { echo "FAIL: Makefile does not delegate to bicameral-mind"; exit 1; }

# DRY_RUN debate works via delegation
DEBATE_TOPIC="make-target-test" DEBATE_ISSUE_SLUG="make-test-$$" DRY_RUN=true \
  make -C "$REPO_ROOT" debate || { echo "FAIL: make debate exited non-zero"; exit 1; }

echo "PASS: Makefile delegation targets valid"
