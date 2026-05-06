#!/usr/bin/env bash
# Verify bicameral-mind submodule is correctly linked and functional
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[test_submodule] Checking bicameral-mind submodule..."

[[ -f "$REPO_ROOT/.gitmodules" ]] || { echo "FAIL: .gitmodules not found"; exit 1; }
grep -q "bicameral-mind" "$REPO_ROOT/.gitmodules" || { echo "FAIL: bicameral-mind not in .gitmodules"; exit 1; }
[[ -f "$REPO_ROOT/bicameral-mind/Makefile" ]] || { echo "FAIL: bicameral-mind/Makefile not found — run: git submodule update --init"; exit 1; }
[[ -f "$REPO_ROOT/bicameral-mind/agents/logicagent/agent.yaml" ]] || { echo "FAIL: logicagent config missing in submodule"; exit 1; }
make -C "$REPO_ROOT/bicameral-mind" help > /dev/null 2>&1 || { echo "FAIL: bicameral-mind Makefile not functional"; exit 1; }

echo "PASS: bicameral-mind submodule correctly linked"
