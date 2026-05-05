#!/usr/bin/env bash
# Cycle 8 RED→GREEN: Debate Record has confidence field; high score sets escalation=true
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[test_escalation] Testing confidence scoring and escalation flag..."

# High-confidence debate (stub forces 0.90)
DEBATE_TOPIC="escalation-high-confidence-test" \
DEBATE_ISSUE_SLUG="esc-high-$$" \
DEBATE_CONFIDENCE="0.90" \
  bash "$REPO_ROOT/scripts/run_debate.sh" --dry-run

RECORD=$(ls -t "$REPO_ROOT/debates"/*.md 2>/dev/null | head -1)
[[ -n "$RECORD" ]] || { echo "FAIL: no record"; exit 1; }

grep -q "^confidence:" "$RECORD" || { echo "FAIL: confidence field missing"; exit 1; }
grep -q "escalation: true" "$RECORD" || { echo "FAIL: high confidence (0.90) should set escalation: true"; exit 1; }

# Low-confidence debate
DEBATE_TOPIC="escalation-low-confidence-test" \
DEBATE_ISSUE_SLUG="esc-low-$$" \
DEBATE_CONFIDENCE="0.40" \
  bash "$REPO_ROOT/scripts/run_debate.sh" --dry-run

RECORD_LOW=$(ls -t "$REPO_ROOT/debates"/*.md 2>/dev/null | head -1)
grep -q "escalation: false" "$RECORD_LOW" || { echo "FAIL: low confidence (0.40) should set escalation: false"; exit 1; }

echo "PASS: confidence scoring and escalation flags correct"
