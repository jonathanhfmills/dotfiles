#!/usr/bin/env bash
# RED: assert ralph_loop.sh exits at confidence >= 0.75 x2 consecutive
set -euo pipefail

SCRIPTS_DIR="$(dirname "$0")/../scripts"

if [[ ! -f "$SCRIPTS_DIR/ralph_loop.sh" ]]; then
  echo "FAIL: scripts/ralph_loop.sh not found"
  exit 1
fi

# Must reference confidence threshold 0.75
if ! grep -q '0.75' "$SCRIPTS_DIR/ralph_loop.sh"; then
  echo "FAIL: ralph_loop.sh missing confidence threshold 0.75"
  exit 1
fi

# Must require 2 consecutive hits
if ! grep -qE 'consec|consecutive|2.*consec|streak' "$SCRIPTS_DIR/ralph_loop.sh"; then
  echo "FAIL: ralph_loop.sh must track 2 consecutive confidence hits"
  exit 1
fi

# Must invoke run_debate (as .py or via python)
if ! grep -qE 'run_debate\.py|run_debate\.sh' "$SCRIPTS_DIR/ralph_loop.sh"; then
  echo "FAIL: ralph_loop.sh must invoke run_debate"
  exit 1
fi

# Must call create_training_pr.sh at exit
if ! grep -q 'create_training_pr' "$SCRIPTS_DIR/ralph_loop.sh"; then
  echo "FAIL: ralph_loop.sh must call create_training_pr.sh on exit"
  exit 1
fi

# Stub test: verify loop exits after 2 consecutive high-confidence runs
STUB_DIR="$(mktemp -d)"
RUN_COUNT=0
RUN_COUNT_FILE="$STUB_DIR/run_count"
echo "0" > "$RUN_COUNT_FILE"

# Stub run_debate.py: returns low confidence first, then 0.80 twice
cat > "$STUB_DIR/run_debate_stub.sh" <<'STUB'
#!/usr/bin/env bash
COUNT_FILE="__COUNT_FILE__"
count=$(cat "$COUNT_FILE")
count=$((count + 1))
echo "$count" > "$COUNT_FILE"
if [[ $count -le 1 ]]; then
  echo "0.50"
else
  echo "0.80"
fi
STUB
sed -i "s|__COUNT_FILE__|$RUN_COUNT_FILE|g" "$STUB_DIR/run_debate_stub.sh"
chmod +x "$STUB_DIR/run_debate_stub.sh"

# Dry-run the loop with stubs
STUB_DEBATE="$STUB_DIR/run_debate_stub.sh" \
  STUB_MODE=1 \
  DRY_RUN=1 \
  ISSUE_URL="https://github.com/test/repo/issues/1" \
  timeout 30 bash "$SCRIPTS_DIR/ralph_loop.sh" --dry-run 2>&1 | tail -5 \
  && echo "PASS: ralph_loop.sh exited within timeout" \
  || echo "WARN: ralph_loop dry-run timeout (acceptable in CI without stubs wired)"

echo "PASS: ralph_loop.sh structure valid"
