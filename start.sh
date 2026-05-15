#!/usr/bin/env bash
# Starts the Docker stack (mediamtx + birdnet-go) and the host-side mic capture bridge.
# macOS cannot pass USB audio directly into Docker containers, so ffmpeg runs on
# the host and pushes each mic stream to mediamtx via RTSP.
set -e

# ── Prerequisites ──────────────────────────────────────────────────────────────

if [ ! -f .env ]; then
    echo "Error: .env not found."
    echo "  cp .env.example .env"
    echo "  Then fill in MIC_DEVICE (run ./find-mic.sh) and your coordinates in config/config.yaml"
    exit 1
fi

source .env

if [ -z "${MIC_DEVICE}" ]; then
    echo "Error: MIC_DEVICE is not set in .env"
    echo "  Run ./find-mic.sh to discover your USB mic index, then set it in .env"
    exit 1
fi

command -v ffmpeg >/dev/null 2>&1 || {
    echo "Error: ffmpeg not found. Install it with: brew install ffmpeg"
    exit 1
}

command -v docker >/dev/null 2>&1 || {
    echo "Error: docker not found."
    exit 1
}

# ── Stop any leftover mic captures ─────────────────────────────────────────────

for pidfile in .mic*.pid; do
    [ -f "$pidfile" ] || continue
    OLD_PID=$(cat "$pidfile")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Stopping previous mic capture (PID $OLD_PID)..."
        kill "$OLD_PID"
    fi
    rm -f "$pidfile"
done

# ── Start Docker stack ─────────────────────────────────────────────────────────

echo "Starting mediamtx and birdnet-go..."
docker compose up -d

echo "Waiting for mediamtx RTSP server to be ready..."
for i in $(seq 1 10); do
    if nc -z localhost 8554 2>/dev/null; then
        break
    fi
    sleep 1
done

# ── Helper: start one ffmpeg mic capture ──────────────────────────────────────

start_mic() {
    local device="$1" rtsp_path="$2" label="$3" pidfile="$4"

    echo "Starting mic capture: ${label} (device :${device} → rtsp://localhost:8554/${rtsp_path})..."
    ffmpeg \
        -f avfoundation \
        -i ":${device}" \
        -acodec aac \
        -ar 48000 \
        -ac 1 \
        -b:a 256k \
        -f rtsp \
        -rtsp_transport tcp \
        "rtsp://localhost:8554/${rtsp_path}" \
        -loglevel warning \
        >> /tmp/bird-ears-ffmpeg.log 2>&1 &

    local pid=$!
    echo $pid > "$pidfile"

    sleep 2
    if ! kill -0 "$pid" 2>/dev/null; then
        echo ""
        echo "Error: mic capture failed for ${label}. Check the log:"
        echo "  cat /tmp/bird-ears-ffmpeg.log"
        echo ""
        echo "Common causes:"
        echo "  - Wrong device index (run ./find-mic.sh)"
        echo "  - Terminal missing microphone permission (System Settings → Privacy & Security → Microphone)"
        docker compose down
        exit 1
    fi
}

# ── Start mic captures ─────────────────────────────────────────────────────────

start_mic "${MIC_DEVICE}" "birdmic-hermes" "Hermes" ".mic1.pid"

if [ -n "${MIC_DEVICE_2}" ]; then
    start_mic "${MIC_DEVICE_2}" "birdmic-comica" "Comica VM30" ".mic2.pid"
fi

PORT=${WEB_PORT:-8080}
echo ""
echo "Bird ears running!"
echo "  Web UI:  http://localhost:${PORT}"
echo "  Logs:    docker compose logs -f birdnet-go"
echo "  Mic log: tail -f /tmp/bird-ears-ffmpeg.log"
echo "  Stop:    ./stop.sh"
