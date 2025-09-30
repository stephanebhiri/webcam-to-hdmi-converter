# Webcam to HDMI Converter (Framebuffer/KMS)

Converts any UVC webcam to HDMI output at 1080p using **GStreamer + Linux Framebuffer**.

## ✨ Key Features

- **No X11/Wayland** - Direct framebuffer rendering via `/dev/fb0`
- **Lightweight** - Uses GStreamer pipeline: webcam → decode → scale → framebuffer
- **Auto-start** - Boots directly to webcam feed
- **Crash resilient** - Automatic restart on failure
- **Hotplug support** - Detects webcam plug/unplug

## Architecture

```
UVC Webcam (/dev/videoX)
    ↓
v4l2src (capture MJPEG)
    ↓
jpegdec (decode)
    ↓
videoconvert + videoscale
    ↓
1920x1080 output
    ↓
fbdevsink (/dev/fb0)
    ↓
HDMI Output
```

## Installation

```bash
cd ~/webcam-hdmi-converter
sudo ./install.sh
```

Installs:
- GStreamer with all plugins
- Systemd service (webcam-hdmi-converter-kms)
- Udev rules for hotplug
- v4l-utils for device detection

## Usage

Plug in any UVC webcam → video appears on HDMI within seconds.

### Management

```bash
# Service control
sudo systemctl status webcam-hdmi-converter-kms
sudo systemctl restart webcam-hdmi-converter-kms
sudo systemctl stop webcam-hdmi-converter-kms

# Logs
sudo journalctl -u webcam-hdmi-converter-kms -f
tail -f /var/log/webcam-hdmi-converter.log

# Check video devices
ls -l /dev/video*
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

## Troubleshooting

### No video on HDMI

1. Check framebuffer device:
   ```bash
   ls -l /dev/fb0
   fbset -i
   ```

2. Check webcam detection:
   ```bash
   v4l2-ctl --list-devices
   ```

3. Test GStreamer manually:
   ```bash
   sudo gst-launch-1.0 v4l2src device=/dev/video0 ! jpegdec ! fbdevsink device=/dev/fb0
   ```

### Service won't start

```bash
sudo journalctl -u webcam-hdmi-converter-kms -n 50
```

### Performance issues

The current pipeline uses software decoding. For better performance on RK3588, you could use hardware acceleration with `mppvideodec` if available.

## Technical Details

- **Video sink**: fbdevsink (Linux framebuffer)
- **Input formats**: MJPEG (preferred), YUYV
- **Output**: 1920x1080 scaled to framebuffer resolution
- **Latency**: ~100-200ms (software decode)
- **CPU usage**: ~20-30% on RK3588 (1 core)

## Comparison with X11 Version

| Feature | Framebuffer | X11/ffplay |
|---------|-------------|------------|
| Dependencies | GStreamer only | X11 + ffmpeg |
| Memory usage | ~25 MB | ~60 MB |
| Boot time | Faster | Slower (X startup) |
| Complexity | Lower | Higher |
| GPU accel | Via fbdev | Via X11/DRI |

## Files

- `webcam-display-kms.sh` - Main GStreamer script
- `webcam-hdmi-converter-kms.service` - Systemd service
- `99-webcam-hotplug.rules` - Udev hotplug rules
- `install.sh` - Installation script