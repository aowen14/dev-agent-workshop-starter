#!/usr/bin/env bash
# Reset between demo acts: stop the host API, revert any host edits.
# Does NOT touch the sandbox — it stays warm for the good-path act.
set -euo pipefail

cd "$(dirname "$0")/.."

PID_FILE=/tmp/workshop-host-api.pid
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo ">> Stopping host FastAPI (pid $PID)..."
        kill "$PID" || true
    fi
    rm -f "$PID_FILE"
fi

echo ">> Reverting any speculative edits to host source..."
git checkout -- src/ tests/ pyproject.toml uv.lock 2>/dev/null || true

echo ">> Host clean. Sandbox is still warm (project: workshop-demo)."
