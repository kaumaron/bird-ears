#!/usr/bin/env bash
set -e

for pidfile in .mic*.pid; do
    [ -f "$pidfile" ] || continue
    PID=$(cat "$pidfile")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "Mic capture stopped (PID $PID)."
    fi
    rm -f "$pidfile"
done

docker compose down
echo "Bird ears stopped."
