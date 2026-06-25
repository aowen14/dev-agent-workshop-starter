#!/usr/bin/env bash
# Show the in-memory app running on the host. This is the "before" state
# the demo references: a small FastAPI app whose database is a Python dict.
set -euo pipefail

cd "$(dirname "$0")/.."

PID_FILE=/tmp/workshop-host-api.pid
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo ">> Host API already running (pid $(cat "$PID_FILE")). Skipping."
else
    echo ">> Starting in-memory FastAPI on host port 8001..."
    uv run uvicorn src.main:app --host 0.0.0.0 --port 8001 --reload \
        > /tmp/workshop-host-api.log 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2
fi

echo
echo ">> Live at http://localhost:8001/products"
echo ">> Stop with ./demo/30-reset.sh"
