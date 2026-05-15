# bird-ears

Real-time bird call detection for macOS using [BirdNET-Go](https://github.com/tphakala/birdnet-go) and one or more USB microphones. Runs entirely in Docker except for a thin ffmpeg audio bridge (macOS doesn't support USB audio passthrough into containers).

## Architecture

```
USB mic(s)
  └── ffmpeg (macOS host)
        └── mediamtx (Docker) — RTSP relay
              └── birdnet-go (Docker) — detection + web UI
```

## Requirements

- macOS with Docker Desktop
- `ffmpeg`: `brew install ffmpeg`
- One or more USB microphones

## Setup

**1. Find your mic device indices**

```bash
./find-mic.sh
```

**2. Configure**

```bash
cp .env.example .env
```

Edit `.env`:
- `MIC_DEVICE` — primary mic index from `find-mic.sh`
- `MIC_DEVICE_2` — optional second mic (leave blank to disable)
- `TZ` — your timezone

Edit `config/config.yaml`:
- `birdnet.latitude` / `birdnet.longitude` — your location (improves species filtering)

**3. Grant microphone access**

System Settings → Privacy & Security → Microphone → enable your terminal app.

## Usage

```bash
./start.sh   # start everything
./stop.sh    # stop everything
```

Web UI: **http://localhost:8080**

Logs:
```bash
docker compose logs -f birdnet-go
tail -f /tmp/bird-ears-ffmpeg.log
```

## Configuration

`config/config.yaml` is auto-expanded by BirdNET-Go on first run. Key settings:

| Setting | Description |
|---|---|
| `birdnet.threshold` | Confidence minimum (0.0–1.0, default 0.7) |
| `birdnet.sensitivity` | Sigmoid sensitivity (0.1–1.5, default 1.0) |
| `birdnet.latitude/longitude` | Location for species range filtering |
| `realtime.interval` | Seconds before re-reporting the same species (default 15) |
| `realtime.audio.export.type` | Clip format: `wav`, `flac`, `mp3`, `aac` |

Detected clips are saved to `data/clips/`.
