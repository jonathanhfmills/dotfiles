#!/usr/bin/env bash
# Cycle 4 RED→GREEN: debate loop produces 3 turns in Debate Record (dry-run)
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[test_debate_loop] Running dry-run debate loop..."

DEBATE_TOPIC="test: 3-turn loop validation" \
DEBATE_ISSUE_SLUG="loop-test-$$" \
  bash "$REPO_ROOT/scripts/run_debate.sh" --dry-run

RECORD=$(ls -t "$REPO_ROOT/debates"/*.md 2>/dev/null | head -1)
[[ -n "$RECORD" ]] || { echo "FAIL: no record found"; exit 1; }

TURN_COUNT=$(grep -c "^## Turn" "$RECORD" || true)
[[ "$TURN_COUNT" -ge 3 ]] || { echo "FAIL: expected ≥3 turns, got $TURN_COUNT in $RECORD"; exit 1; }

# Assert agent names appear
grep -q "nullclaw" "$RECORD" || { echo "FAIL: nullclaw not in record"; exit 1; }
grep -q "hermes" "$RECORD" || { echo "FAIL: hermes not in record"; exit 1; }

echo "PASS: debate loop produces 3-turn record"
