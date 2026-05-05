#!/usr/bin/env bash
# RED: assert escalate.sh invokes claude --print with ISSUE_URL
set -euo pipefail

SCRIPTS_DIR="$(dirname "$0")/../scripts"

if [[ ! -f "$SCRIPTS_DIR/escalate.sh" ]]; then
  echo "FAIL: scripts/escalate.sh not found"
  exit 1
fi

# Must invoke claude --print
if ! grep -q 'claude --print' "$SCRIPTS_DIR/escalate.sh"; then
  echo "FAIL: escalate.sh must invoke 'claude --print'"
  exit 1
fi

# Must pass ISSUE_URL as sole context
if ! grep -q 'ISSUE_URL' "$SCRIPTS_DIR/escalate.sh"; then
  echo "FAIL: escalate.sh must use ISSUE_URL"
  exit 1
fi

# Must NOT pass a plan file
if grep -q '\-\-plan\|plan\.md\|plan_file' "$SCRIPTS_DIR/escalate.sh"; then
  echo "FAIL: escalate.sh must not pass a plan file (issue URL is sole context)"
  exit 1
fi

# Dry-run: stub claude to capture invocation
ISSUE_URL="https://github.com/test/repo/issues/1"
STUB_DIR="$(mktemp -d)"
cat > "$STUB_DIR/claude" <<'STUB'
#!/usr/bin/env bash
echo "STUB_CLAUDE_CALLED: $@"
STUB
chmod +x "$STUB_DIR/claude"

OUTPUT=$(PATH="$STUB_DIR:$PATH" ISSUE_URL="$ISSUE_URL" bash "$SCRIPTS_DIR/escalate.sh" 2>&1)
rm -rf "$STUB_DIR"

if ! echo "$OUTPUT" | grep -q "STUB_CLAUDE_CALLED"; then
  echo "FAIL: escalate.sh did not invoke claude"
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "$ISSUE_URL"; then
  echo "FAIL: escalate.sh did not pass ISSUE_URL to claude"
  exit 1
fi

echo "PASS: escalate.sh invokes claude --print with ISSUE_URL"
