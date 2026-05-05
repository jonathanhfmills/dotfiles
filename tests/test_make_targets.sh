#!/usr/bin/env bash
# Cycle 5 RED→GREEN: Makefile targets exist and help text shows them
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[test_make_targets] Checking Makefile targets..."

for target in debate observer agent-start hindsight test; do
  grep -q "^${target}:" "$REPO_ROOT/Makefile" || { echo "FAIL: target '$target' not in Makefile"; exit 1; }
done

# Help text includes Living Code section (capture first to avoid broken pipe)
HELP_OUT=$(make -C "$REPO_ROOT" help 2>/dev/null || true)
echo "$HELP_OUT" | grep -q "debate" || { echo "FAIL: 'debate' missing from make help"; exit 1; }
echo "$HELP_OUT" | grep -q "observer" || { echo "FAIL: 'observer' missing from make help"; exit 1; }

# debate target runs without error (dry-run via env)
DEBATE_TOPIC="make-target-test" DEBATE_ISSUE_SLUG="make-test-$$" DRY_RUN=true \
  make -C "$REPO_ROOT" debate || { echo "FAIL: make debate exited non-zero"; exit 1; }

echo "PASS: Makefile targets valid"
