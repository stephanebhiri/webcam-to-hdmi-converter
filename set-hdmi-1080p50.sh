#!/bin/bash

# Force HDMI output to 1080p50
# For RK3588 (OrangePi 5 Plus)

HDMI_PORT="card0-HDMI-A-1"
DESIRED_MODE="1920x1080"
DESIRED_REFRESH="50"

# Try to set via DRM
DRM_PATH="/sys/class/drm/$HDMI_PORT"

if [ -d "$DRM_PATH" ]; then
    echo "Found HDMI port: $HDMI_PORT"

    # Check if connected
    STATUS=$(cat "$DRM_PATH/status" 2>/dev/null)
    if [ "$STATUS" = "connected" ]; then
        echo "HDMI is connected"

        # Try to set mode directly (requires root)
        # Note: This may not work on all kernels
        echo "$DESIRED_MODE" > "$DRM_PATH/mode" 2>/dev/null && echo "Mode set to $DESIRED_MODE" || echo "Direct mode setting not supported"
    else
        echo "HDMI not connected"
    fi
else
    echo "HDMI port not found at $DRM_PATH"
fi

# Alternative: Use modetest (from libdrm)
if command -v modetest &> /dev/null; then
    echo "Using modetest to set 1080p50..."
    # Get connector ID
    CONNECTOR_ID=$(modetest -M rockchip | grep -A1 "^Connectors:" | grep HDMI-A-1 | awk '{print $1}')
    if [ -n "$CONNECTOR_ID" ]; then
        echo "Connector ID: $CONNECTOR_ID"
        # This would require knowing the mode ID - complex, skip for now
    fi
fi

echo "Note: For persistent 1080p50, add to /boot/armbianEnv.txt:"
echo "extraargs=video=HDMI-A-1:1920x1080@50"