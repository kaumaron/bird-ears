# bird-ears

Real-time bird call detection for macOS using [BirdNET-Go](https://github.com/tphakala/birdnet-go) and one or more microphones. Runs entirely in Docker except for a thin ffmpeg audio bridge (macOS doesn't support USB audio passthrough into containers).

## Architecture

```
mic(s) — USB or iPhone via Continuity Microphone
  └── ffmpeg (macOS host) — resolves device names, pushes RTSP
        └── mediamtx (Docker) — RTSP relay
              └── birdnet-go (Docker) — detection + web UI
```

## Requirements

- macOS with Docker Desktop
- `ffmpeg`: `brew install ffmpeg`
- One or more microphones (USB or iPhone via Continuity Microphone)

## Setup

**1. Find your mic device names**

```bash
./find-mic.sh
```

Plug in USB mics first. For iPhone: enable WiFi and Bluetooth on both devices, sign into the same Apple ID, then lock the iPhone — it appears automatically as a Continuity Microphone.

**2. Configure**

```bash
cp .env.example .env
cp config/config.yaml.example config/config.yaml
```

Edit `.env`:
- `MIC_DEVICE` — primary mic name from `find-mic.sh` (quoted if it contains spaces or parentheses)
- `MIC_DEVICE_2`, `MIC_DEVICE_3` — optional additional mics (leave blank to disable)
- `BIRDNET_LATITUDE` / `BIRDNET_LONGITUDE` — your location (improves species filtering)
- `TZ` — your timezone

**3. Grant microphone access**

System Settings → Privacy & Security → Microphone → enable your terminal app.

## Usage

```bash
./start.sh   # start everything (safe to re-run; skips docker if already running)
./stop.sh    # stop everything
```

Web UI: **http://localhost:8080**

Logs:
```bash
docker compose logs -f birdnet-go
tail -f /tmp/bird-ears-ffmpeg.log
```

## Adding or removing mics at runtime

`./start.sh` resolves device names to indices at startup and skips any mic that isn't currently available. To add a newly connected mic without restarting Docker, just re-run `./start.sh` — it will detect the stack is already running and only launch the missing ffmpeg streams.

Removing a stream or adding a new RTSP path to BirdNET-Go requires a container restart to reload `config/config.yaml`.

## Notes

- Device indices in avfoundation shift whenever devices are connected or disconnected. `start.sh` looks up the current index by name at each run, so `.env` stays stable.
- `config/config.yaml` is auto-expanded by BirdNET-Go on first run and treated as a runtime artifact (gitignored). Edit `config/config.yaml.example` to change the committed defaults.

## Configuration

Key settings in `config/config.yaml`:

| Setting | Description |
|---|---|
| `birdnet.threshold` | Confidence minimum (0.0–1.0, default 0.7) |
| `birdnet.sensitivity` | Sigmoid sensitivity (0.1–1.5, default 1.0) |
| `realtime.interval` | Seconds before re-reporting the same species (default 15) |
| `realtime.audio.export.type` | Clip format: `wav`, `flac`, `mp3`, `aac` |

Location is set via `BIRDNET_LATITUDE` / `BIRDNET_LONGITUDE` in `.env`.

Detected clips are saved to `data/clips/`.
