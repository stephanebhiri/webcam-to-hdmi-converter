#!/bin/bash

# Installation script for Webcam to HDMI Converter
# Run with: sudo ./install.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="actua"

echo "Installing Webcam to HDMI Converter..."

# Install required packages
echo "Installing required packages..."
apt-get update
apt-get install -y \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-alsa \
    fbset \
    v4l-utils

# Create log file
touch /var/log/webcam-hdmi-converter.log
chmod 666 /var/log/webcam-hdmi-converter.log

# Install systemd service
echo "Installing systemd service..."
cp "$SCRIPT_DIR/webcam-hdmi-converter-kms.service" /etc/systemd/system/
systemctl daemon-reload

# Install udev rule
echo "Installing udev rule for hotplug detection..."
cp "$SCRIPT_DIR/99-webcam-hotplug.rules" /etc/udev/rules.d/
# Update udev rule to use new service name
sed -i 's/webcam-hdmi-converter.service/webcam-hdmi-converter-kms.service/g' /etc/udev/rules.d/99-webcam-hotplug.rules
udevadm control --reload-rules
udevadm trigger

# Configure HDMI to 1080p50
echo "Configuring HDMI output to 1080p50..."

# Add kernel parameter if not already present
if ! grep -q "video=HDMI-A-1:1920x1080@50" /boot/armbianEnv.txt 2>/dev/null; then
    sed -i 's/extraargs=\(.*\)/extraargs=\1 video=HDMI-A-1:1920x1080@50/' /boot/armbianEnv.txt 2>/dev/null || echo "Could not modify /boot/armbianEnv.txt"
fi

# Install HDMI mode forcing service
cp "$SCRIPT_DIR/force-hdmi-1080p50.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable force-hdmi-1080p50.service

# Enable and start service
echo "Enabling and starting service..."
systemctl enable webcam-hdmi-converter-kms.service
systemctl start webcam-hdmi-converter-kms.service

echo ""
echo "Installation complete!"
echo ""
echo "Service status:"
systemctl status webcam-hdmi-converter-kms.service --no-pager || true
echo ""
echo "Useful commands:"
echo "  - Check status: sudo systemctl status webcam-hdmi-converter-kms"
echo "  - View logs: sudo journalctl -u webcam-hdmi-converter-kms -f"
echo "  - View log file: tail -f /var/log/webcam-hdmi-converter.log"
echo "  - Restart service: sudo systemctl restart webcam-hdmi-converter-kms"
echo "  - Stop service: sudo systemctl stop webcam-hdmi-converter-kms"
echo ""
echo "The converter uses GStreamer + Linux Framebuffer (no X11/Wayland needed)"
echo "and will automatically start on boot and restart on crashes."