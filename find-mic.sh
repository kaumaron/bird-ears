#!/usr/bin/env bash
set -e

command -v ffmpeg >/dev/null 2>&1 || {
    echo "ffmpeg not found. Install it with:"
    echo "  brew install ffmpeg"
    exit 1
}

echo "Available audio input devices (look for your USB mic):"
echo ""
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | awk '/AVFoundation audio devices/,0' \
    | grep -v "^$" \
    | head -30

echo ""
echo "Set the number shown in brackets in your .env file:"
echo "  MIC_DEVICE=1   (for a device shown as [1])"
echo ""
echo "Also open System Settings → Privacy & Security → Microphone"
echo "and make sure Terminal has microphone access."
