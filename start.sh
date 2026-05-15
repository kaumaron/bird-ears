#!/usr/bin/env bash
# Starts the Docker stack (mediamtx + birdnet-go) and the host-side mic capture bridge.
# macOS cannot pass USB audio directly into Docker containers, so ffmpeg runs on
# the host and pushes the mic stream to mediamtx via RTSP.
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

# ── Stop any leftover mic capture ──────────────────────────────────────────────

if [ -f .mic.pid ]; then
    OLD_PID=$(cat .mic.pid)
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Stopping previous mic capture (PID $OLD_PID)..."
        kill "$OLD_PID"
    fi
    rm -f .mic.pid
fi

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

# ── Start mic capture ──────────────────────────────────────────────────────────

echo "Starting mic capture from avfoundation device :${MIC_DEVICE}..."
ffmpeg \
    -f avfoundation \
    -i ":${MIC_DEVICE}" \
    -acodec aac \
    -ar 48000 \
    -ac 1 \
    -b:a 256k \
    -f rtsp \
    -rtsp_transport tcp \
    rtsp://localhost:8554/birdmic \
    -loglevel warning \
    >> /tmp/bird-ears-ffmpeg.log 2>&1 &

MIC_PID=$!
echo $MIC_PID > .mic.pid

# Verify the process actually started
sleep 2
if ! kill -0 "$MIC_PID" 2>/dev/null; then
    echo ""
    echo "Error: mic capture failed to start. Check the log:"
    echo "  cat /tmp/bird-ears-ffmpeg.log"
    echo ""
    echo "Common causes:"
    echo "  - Wrong MIC_DEVICE index (run ./find-mic.sh)"
    echo "  - Terminal missing microphone permission (System Settings → Privacy & Security → Microphone)"
    docker compose down
    exit 1
fi

PORT=${WEB_PORT:-8080}
echo ""
echo "Bird ears running!"
echo "  Web UI:  http://localhost:${PORT}"
echo "  Logs:    docker compose logs -f birdnet-go"
echo "  Mic log: tail -f /tmp/bird-ears-ffmpeg.log"
echo "  Stop:    ./stop.sh"
