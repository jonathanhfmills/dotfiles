#!/usr/bin/env bash
# Cycle 1 RED: assert Debate Record format is correct
set -euo pipefail

DEBATES_DIR="$(dirname "$0")/../debates"
SCRIPTS_DIR="$(dirname "$0")/../scripts"

echo "[test_debate_record] Creating test debate record..."

# Run the debate script with a test topic
DEBATE_ISSUE_SLUG="test-issue-001" \
DEBATE_TOPIC="test: feelings vs logic on tab indentation" \
  bash "$SCRIPTS_DIR/run_debate.sh" --dry-run

# Find the most recent debate file
RECORD=$(ls -t "$DEBATES_DIR"/*.md 2>/dev/null | head -1)

if [[ -z "$RECORD" ]]; then
  echo "FAIL: no debate record written to $DEBATES_DIR"
  exit 1
fi

echo "[test_debate_record] Found: $RECORD"

# Assert required frontmatter fields
for field in date issue_slug agents confidence turns; do
  if ! grep -q "^${field}:" "$RECORD"; then
    echo "FAIL: missing frontmatter field '$field' in $RECORD"
    exit 1
  fi
done

# Assert confidence is numeric 0-1
CONFIDENCE=$(grep "^confidence:" "$RECORD" | awk '{print $2}')
if ! echo "$CONFIDENCE" | grep -qE '^0(\.[0-9]+)?$|^1(\.0+)?$'; then
  echo "FAIL: confidence '$CONFIDENCE' is not a 0-1 float"
  exit 1
fi

# Assert at least one turn block exists
if ! grep -q "^## Turn" "$RECORD"; then
  echo "FAIL: no turn blocks found in $RECORD"
  exit 1
fi

echo "PASS: debate record format valid"
