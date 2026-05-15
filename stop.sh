#!/usr/bin/env bash
set -e

if [ -f .mic.pid ]; then
    PID=$(cat .mic.pid)
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "Mic capture stopped (PID $PID)."
    fi
    rm -f .mic.pid
fi

docker compose down
echo "Bird ears stopped."
