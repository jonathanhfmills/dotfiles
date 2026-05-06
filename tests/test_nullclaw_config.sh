#!/usr/bin/env bash
# Cycle 2 RED→GREEN: nullclaw agent.yaml parses + required fields present
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_ROOT/agents/nullclaw/agent.yaml"

echo "[test_nullclaw_config] Checking $CONFIG..."

[[ -f "$CONFIG" ]] || { echo "FAIL: $CONFIG not found"; exit 1; }
[[ -f "$REPO_ROOT/agents/nullclaw/SOUL.md" ]] || { echo "FAIL: SOUL.md missing"; exit 1; }
[[ -f "$REPO_ROOT/agents/nullclaw/RULES.md" ]] || { echo "FAIL: RULES.md missing"; exit 1; }

for field in name model memory; do
  grep -q "^${field}:" "$CONFIG" || { echo "FAIL: missing field '$field' in $CONFIG"; exit 1; }
done

grep -q "lucid" "$CONFIG" || { echo "FAIL: lucid memory provider not configured"; exit 1; }
grep -q "openai_compatible" "$CONFIG" || { echo "FAIL: openai_compatible provider not set"; exit 1; }

echo "PASS: nullclaw config valid"
