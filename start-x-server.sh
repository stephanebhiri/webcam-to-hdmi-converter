#!/bin/bash

# Start X server for webcam display
# This script starts a minimal X server on DISPLAY :0

export DISPLAY=:0

# Kill any existing X server on :0
killall Xorg 2>/dev/null || true
sleep 1

# Start X server
startx -- :0 vt1 &

# Wait for X to be ready
for i in {1..30}; do
    if xset -display :0 q &>/dev/null; then
        echo "X server ready on :0"
        exit 0
    fi
    sleep 1
done

echo "X server failed to start"
exit 1