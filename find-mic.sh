#!/usr/bin/env bash
set -e

command -v ffmpeg >/dev/null 2>&1 || {
    echo "ffmpeg not found. Install it with:"
    echo "  brew install ffmpeg"
    exit 1
}

echo "Available audio input devices:"
echo ""
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | awk '/AVFoundation audio devices/,0' \
    | grep -E '\[[0-9]+\]'

echo ""
echo "Set the device NAME (quoted) in your .env — start.sh resolves names to indices at runtime:"
echo "  MIC_DEVICE=\"Hermes (17) Microphone\""
echo "  MIC_DEVICE_2=\"Comica_VM30 TX\""
echo ""
echo "Also open System Settings → Privacy & Security → Microphone"
echo "and make sure Terminal has microphone access."
