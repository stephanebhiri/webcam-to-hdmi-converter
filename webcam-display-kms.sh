#!/bin/bash

# Webcam to HDMI Converter Script (Framebuffer Direct)
# No X11/Wayland needed - uses Linux framebuffer for direct HDMI output
# Displays any UVC webcam on HDMI output at 1080p via GStreamer + fbdevsink

LOG_FILE="/var/log/webcam-hdmi-converter.log"
RETRY_DELAY=5
MAX_RETRIES_NO_DEVICE=12  # 1 minute total wait
GST_PID=""

# Cleanup function to kill GStreamer process on exit
cleanup() {
    if [ -n "$GST_PID" ] && kill -0 "$GST_PID" 2>/dev/null; then
        log "Cleaning up GStreamer process (PID: $GST_PID)..."
        kill -TERM "$GST_PID" 2>/dev/null
        sleep 1
        # Force kill if still alive
        if kill -0 "$GST_PID" 2>/dev/null; then
            kill -KILL "$GST_PID" 2>/dev/null
        fi
    fi
}

# Register cleanup on script exit
trap cleanup EXIT SIGTERM SIGINT

# Ensure log file exists with correct permissions
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null || true
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Webcam-HDMI converter starting (KMS mode)..."

# Disable console cursor and unbind vtconsole to free planes
echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null || true
echo 0 > /sys/class/vtconsole/vtcon0/bind 2>/dev/null || true
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null || true

# Function to find the first available video capture device
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

# Function to detect best format and resolution
detect_webcam_format() {
    local device=$1
    local formats=$(v4l2-ctl --device="$device" --list-formats-ext 2>/dev/null)

    # Check for MJPEG support (preferred for bandwidth)
    if echo "$formats" | grep -q "Motion-JPEG"; then
        # Try to find 1920x1080
        if echo "$formats" | grep -A10 "Motion-JPEG" | grep -q "1920x1080"; then
            echo "mjpeg:1920x1080:30"
            return 0
        # Try 1280x720
        elif echo "$formats" | grep -A10 "Motion-JPEG" | grep -q "1280x720"; then
            echo "mjpeg:1280x720:30"
            return 0
        fi
    fi

    # Fallback to YUYV/YUY2
    if echo "$formats" | grep -q "YUYV"; then
        if echo "$formats" | grep -A5 "YUYV" | grep -q "1920x1080"; then
            echo "yuyv:1920x1080:30"
            return 0
        elif echo "$formats" | grep -A5 "YUYV" | grep -q "1280x720"; then
            echo "yuyv:1280x720:30"
            return 0
        fi
    fi

    # Default fallback
    echo "yuyv:640x480:30"
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

    # Get device info
    DEVICE_NAME=$(v4l2-ctl --device="$VIDEO_DEVICE" --info 2>/dev/null | grep 'Card type' | cut -d: -f2 | xargs)
    log "Device: $DEVICE_NAME"

    # Detect best format
    FORMAT_INFO=$(detect_webcam_format "$VIDEO_DEVICE")
    FORMAT=$(echo "$FORMAT_INFO" | cut -d: -f1)
    RESOLUTION=$(echo "$FORMAT_INFO" | cut -d: -f2)
    FRAMERATE=$(echo "$FORMAT_INFO" | cut -d: -f3)

    log "Using format: $FORMAT, resolution: $RESOLUTION @ ${FRAMERATE}fps"

    # Build simple GStreamer pipeline with audio support
    # Let GStreamer negotiate formats automatically
    log "Starting GStreamer pipeline with audio..."

    # Detect if webcam has audio capability
    AUDIO_DEVICE=""
    # Look for USB audio capture devices (webcams with mic)
    AUDIO_CARD=$(arecord -l 2>/dev/null | grep -iE "usb|camera" | grep -oP "carte \K[0-9]+" | head -1)

    if [ -n "$AUDIO_CARD" ]; then
        AUDIO_DEVICE="hw:$AUDIO_CARD,0"
        log "Found USB audio device: $AUDIO_DEVICE (card $AUDIO_CARD)"
    else
        log "No USB audio device found"
    fi

    # Run GStreamer with video and optional audio
    if [ -n "$AUDIO_DEVICE" ]; then
        log "Starting pipeline with audio from $AUDIO_DEVICE"
        gst-launch-1.0 \
            v4l2src device=$VIDEO_DEVICE \
            ! jpegdec \
            ! videoconvert \
            ! videoscale \
            ! video/x-raw,width=1920,height=1080 \
            ! queue leaky=downstream \
            ! fbdevsink device=/dev/fb0 sync=false \
            alsasrc device=$AUDIO_DEVICE buffer-time=20000 latency-time=10000 \
            ! audioconvert \
            ! audioresample \
            ! audio/x-raw,rate=48000,channels=2 \
            ! queue max-size-buffers=2 max-size-time=0 max-size-bytes=0 \
            ! alsasink device=hw:1,0 sync=false buffer-time=20000 latency-time=10000 \
            2>&1 | while read line; do
                # Only log errors and important messages
                if echo "$line" | grep -qiE "(error|erreur|warn|avertissement)"; then
                    log "gst: $line"
                    # Detect fatal audio errors and signal restart
                    if echo "$line" | grep -qiE "(alsasink.*error|audio.*device.*error|périphérique audio|erreur d'écriture)"; then
                        touch "$AUDIO_ERROR_FLAG" 2>/dev/null || true
                    fi
                fi
            done &
        GST_PID=$!

        # HDMI audio hotplug monitor - poll every 3 seconds
        # Create a flag file to track audio errors
        AUDIO_ERROR_FLAG="/tmp/webcam-audio-error-$$"
        rm -f "$AUDIO_ERROR_FLAG"

        (
            LAST_AUDIO_CHECK=0
            while kill -0 "$GST_PID" 2>/dev/null; do
                sleep 3
                # Check if audio error flag was set by error detection
                if [ -f "$AUDIO_ERROR_FLAG" ]; then
                    log "Audio error detected, restarting pipeline..."
                    rm -f "$AUDIO_ERROR_FLAG"
                    kill -TERM "$GST_PID" 2>/dev/null
                    break
                fi

                # Active check: verify HDMI audio device is still writable
                CURRENT_CHECK=$(cat /proc/asound/card1/pcm0p/sub0/status 2>/dev/null | grep -c "state: RUNNING" || echo "0")
                if [ "$CURRENT_CHECK" = "0" ] && [ $LAST_AUDIO_CHECK -gt 2 ]; then
                    # Audio was running but stopped - likely HDMI disconnect
                    log "Audio stream stopped (HDMI disconnect?), restarting pipeline..."
                    kill -TERM "$GST_PID" 2>/dev/null
                    break
                fi
                LAST_AUDIO_CHECK=$((LAST_AUDIO_CHECK + 1))
            done
        ) &
        MONITOR_PID=$!

        wait "$GST_PID"
        kill "$MONITOR_PID" 2>/dev/null || true
    else
        log "No audio device found, video only"
        gst-launch-1.0 \
            v4l2src device=$VIDEO_DEVICE \
            ! jpegdec \
            ! videoconvert \
            ! videoscale \
            ! video/x-raw,width=1920,height=1080 \
            ! queue \
            ! fbdevsink device=/dev/fb0 \
            2>&1 | while read line; do
                # Only log errors and important messages
                if echo "$line" | grep -qiE "(error|erreur|warn|avertissement)"; then
                    log "gst: $line"
                fi
            done &
        GST_PID=$!
        wait "$GST_PID"
    fi

    EXIT_CODE=$?
    log "GStreamer stopped with exit code: $EXIT_CODE"
    GST_PID=""  # Reset PID after process ends

    # If device disappeared, detect it faster
    if [ ! -c "$VIDEO_DEVICE" ]; then
        log "Video device disconnected. Searching for new device..."
        sleep 1
    else
        log "Restarting in $RETRY_DELAY seconds..."
        sleep "$RETRY_DELAY"
    fi
done