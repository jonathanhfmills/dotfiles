#!/usr/bin/env bash
# RED: assert run_debate.py uses gemini/qwen CLIs (not curl)
set -euo pipefail

SCRIPTS_DIR="$(dirname "$0")/../scripts"

if [[ ! -f "$SCRIPTS_DIR/run_debate.py" ]]; then
  echo "FAIL: scripts/run_debate.py not found"
  exit 1
fi

# Must NOT use curl for agent invocation
if grep -q 'curl.*debate/turn' "$SCRIPTS_DIR/run_debate.py"; then
  echo "FAIL: run_debate.py still uses curl for agent invocation"
  exit 1
fi

# Must use hindsight_litellm for Nullclaw
if ! grep -q 'hindsight_litellm' "$SCRIPTS_DIR/run_debate.py"; then
  echo "FAIL: run_debate.py must use hindsight_litellm for Nullclaw"
  exit 1
fi

# Must use qwen_agent for Hermes
if ! grep -q 'qwen_agent' "$SCRIPTS_DIR/run_debate.py"; then
  echo "FAIL: run_debate.py must use qwen_agent for Hermes"
  exit 1
fi

# Must seed from both Lucid and Hindsight before turns
if ! grep -q 'lucid' "$SCRIPTS_DIR/run_debate.py"; then
  echo "FAIL: run_debate.py must query Lucid for pre-debate seed"
  exit 1
fi

# Must accept ISSUE_URL as context
if ! grep -q 'ISSUE_URL\|issue_url' "$SCRIPTS_DIR/run_debate.py"; then
  echo "FAIL: run_debate.py must accept ISSUE_URL"
  exit 1
fi

echo "PASS: run_debate.py uses CLI wrappers (not curl)"
