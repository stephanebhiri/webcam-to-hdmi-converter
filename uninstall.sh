#!/bin/bash

# Uninstallation script for Webcam to HDMI Converter
# Run with: sudo ./uninstall.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "Uninstalling Webcam to HDMI Converter..."

# Stop and disable service
echo "Stopping and disabling service..."
systemctl stop webcam-hdmi-converter.service || true
systemctl disable webcam-hdmi-converter.service || true

# Remove systemd service
echo "Removing systemd service..."
rm -f /etc/systemd/system/webcam-hdmi-converter.service
systemctl daemon-reload

# Remove udev rule
echo "Removing udev rule..."
rm -f /etc/udev/rules.d/99-webcam-hotplug.rules
udevadm control --reload-rules

echo ""
echo "Uninstallation complete!"
echo "Log file /var/log/webcam-hdmi-converter.log was kept for reference."
echo "To remove it: sudo rm /var/log/webcam-hdmi-converter.log"