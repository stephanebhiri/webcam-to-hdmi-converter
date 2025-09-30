#!/bin/bash

# Webcam to HDMI Converter Script
# Displays any UVC webcam on HDMI output at 1080p50
# Auto-restart on crash, resilient design

LOG_FILE="/var/log/webcam-hdmi-converter.log"
DISPLAY=":0"
RETRY_DELAY=5
MAX_RETRIES_NO_DEVICE=12  # 1 minute total wait

# Ensure log file exists with correct permissions
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null || true
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Ensure display is available
export DISPLAY="$DISPLAY"

# Disable screen blanking and power management
xset s off 2>/dev/null
xset -dpms 2>/dev/null
xset s noblank 2>/dev/null

log "Webcam-HDMI converter starting..."

# Function to find the first available video device
find_video_device() {
    for device in /dev/video*; do
        if [ -c "$device" ]; then
            # Check if it's a capture device (not just a metadata device)
            if v4l2-ctl --device="$device" --list-formats 2>/dev/null | grep -q "Video Capture"; then
                echo "$device"
                return 0
            fi
        fi
    done
    return 1
}

# Main loop with crash resilience
retry_count=0
while true; do
    # Find video device
    VIDEO_DEVICE=$(find_video_device)

    if [ -z "$VIDEO_DEVICE" ]; then
        if [ $retry_count -lt $MAX_RETRIES_NO_DEVICE ]; then
            log "No video device found. Waiting... (attempt $((retry_count + 1))/$MAX_RETRIES_NO_DEVICE)"
            retry_count=$((retry_count + 1))
            sleep "$RETRY_DELAY"
            continue
        else
            log "No video device found after $MAX_RETRIES_NO_DEVICE attempts. Continuing to wait..."
            retry_count=0
        fi
        sleep "$RETRY_DELAY"
        continue
    fi

    retry_count=0
    log "Found video device: $VIDEO_DEVICE"

    # Get device capabilities
    DEVICE_INFO=$(v4l2-ctl --device="$VIDEO_DEVICE" --list-formats-ext 2>/dev/null)
    log "Device capabilities: $(v4l2-ctl --device="$VIDEO_DEVICE" --info 2>/dev/null | grep 'Card type' | cut -d: -f2 | xargs)"

    # Try to find best resolution (prefer 1920x1080, fallback to highest available)
    RESOLUTION="1920x1080"
    FRAMERATE="30"

    if echo "$DEVICE_INFO" | grep -q "1920x1080"; then
        RESOLUTION="1920x1080"
        # Try to get 50fps if available, otherwise 30fps
        if echo "$DEVICE_INFO" | grep -A5 "1920x1080" | grep -q "(50.000 fps)"; then
            FRAMERATE="50"
        elif echo "$DEVICE_INFO" | grep -A5 "1920x1080" | grep -q "(30.000 fps)"; then
            FRAMERATE="30"
        fi
    else
        # Get highest available resolution
        RESOLUTION=$(echo "$DEVICE_INFO" | grep "Size:" | head -1 | awk '{print $3}')
    fi

    log "Using resolution: $RESOLUTION @ ${FRAMERATE}fps"

    # Start ffplay with the webcam feed
    # Using ffplay for simplicity and reliability
    # -fs: fullscreen, -an: no audio processing for lower latency
    # -fflags nobuffer: reduce latency
    log "Starting video display..."

    ffplay -f v4l2 \
        -input_format mjpeg \
        -video_size "$RESOLUTION" \
        -framerate "$FRAMERATE" \
        -i "$VIDEO_DEVICE" \
        -vf "scale=1920:1080:flags=bilinear,format=yuv420p" \
        -fs \
        -an \
        -fflags nobuffer \
        -flags low_delay \
        -framedrop \
        -sync video \
        -window_title "Webcam Feed" \
        2>&1 | while read line; do log "ffplay: $line"; done

    EXIT_CODE=$?
    log "Video display stopped with exit code: $EXIT_CODE"

    # If device disappeared, detect it faster
    if [ ! -c "$VIDEO_DEVICE" ]; then
        log "Video device disconnected. Searching for new device..."
        sleep 1
    else
        log "Restarting in $RETRY_DELAY seconds..."
        sleep "$RETRY_DELAY"
    fi
done