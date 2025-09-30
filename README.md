# Webcam to HDMI Converter (OrangePi 5 Plus)

Automatic USB webcam to HDMI output converter for OrangePi 5 Plus (RK3588).

**Architecture**: GStreamer + Linux Framebuffer (no X11/Wayland required)

## ✨ Features

- ✅ Automatic display of any UVC webcam on HDMI
- ✅ Fixed **1080p50** output (HDMI0 = middle port next to Ethernet)
- ✅ Automatic audio support with **ultra-low latency (~20ms)**
- ✅ **Automatic audio recovery** after HDMI cable unplug/replug (3-4s)
- ✅ Automatic startup on boot
- ✅ USB webcam and HDMI hotplug detection
- ✅ Crash resilience (automatic restart)
- ✅ Power outage protection
- ✅ No graphical desktop required (ultra lightweight)

## 🎯 Use Cases

Turn an OrangePi 5 Plus into a standalone **USB webcam → HDMI converter**.

Ideal for:
- Video capture and monitoring
- Live streaming setups
- Event installations
- HDMI video feeds

## 🏗️ Architecture

```
USB Webcam (UVC) @ 30fps MJPEG
    ↓
GStreamer v4l2src
    ↓
MJPEG decode → Scale 1920x1080
    ↓
Linux Framebuffer (/dev/fb0)
    ↓
HDMI0 Output @ 1080p50
```

**Audio** (if available):
```
Webcam microphone (hw:4,0)
    ↓
ALSA (buffer 20ms)
    ↓
HDMI0 audio (hw:1,0 = rockchip-hdmi0)
```

## ⚠️ IMPORTANT: Which HDMI output to use?

The OrangePi 5 Plus has **2 HDMI outputs**:
- **HDMI0** (middle port, next to Ethernet) → **1080p50 + AUDIO** ✅ **← USE THIS ONE**
- HDMI1 (other port) → 1080p60 but NO audio ❌

**Connect your HDMI cable to the middle port** (the one at 1080p50).

## 📦 Installation

```bash
cd ~
git clone https://github.com/stephanebhiri/webcam-hdmi-converter.git
cd webcam-hdmi-converter
sudo ./install.sh
```

The script installs:
- GStreamer with all plugins (base, good, bad, libav, alsa)
- v4l-utils for webcam detection
- systemd service with real-time priority
- udev rules for USB **and HDMI** hotplug
- Forced HDMI 1080p50 configuration

**Then reboot** to activate the HDMI configuration.

## 🚀 Usage

After installation and reboot:

1. Plug in a USB webcam → video appears automatically on HDMI0
2. If the webcam has a microphone → audio outputs automatically on HDMI0
3. If HDMI cable is unplugged → automatic reconnection in 3-4 seconds

That's it! The system works automatically.

## 🛠️ Useful Commands

```bash
# Service status
sudo systemctl status webcam-hdmi-converter-kms

# Real-time logs
sudo journalctl -u webcam-hdmi-converter-kms -f

# Application logs
tail -f /var/log/webcam-hdmi-converter.log

# Restart
sudo systemctl restart webcam-hdmi-converter-kms

# Stop
sudo systemctl stop webcam-hdmi-converter-kms

# List webcams
v4l2-ctl --list-devices

# List audio devices
aplay -l   # playback (HDMI output)
arecord -l # capture (webcam mic)

# Check active HDMI resolution
dmesg | grep "1920x1080" | tail -2
```

## 🔧 Advanced Configuration

### Change audio latency

Edit `/home/actua/webcam-hdmi-converter/webcam-display-kms.sh`:

```bash
# Lines 153 and 158 - buffer-time and latency-time in microseconds
buffer-time=20000 latency-time=10000  # 20ms/10ms (current - very low)
buffer-time=50000 latency-time=25000  # 50ms/25ms (more stable, less responsive)
```

### Change HDMI resolution and refresh rate

By default, the system forces **1080p50** (1920x1080 @ 50Hz) on HDMI0.

To change to **1080p60** or another format:

1. Edit `/boot/armbianEnv.txt`:
   ```bash
   sudo nano /boot/armbianEnv.txt
   ```

2. Modify the `extraargs` line:
   ```bash
   # For 1080p60
   extraargs=cma=256M video=HDMI-A-1:1920x1080M@60eD

   # For 720p60
   extraargs=cma=256M video=HDMI-A-1:1280x720M@60eD

   # For 4K30
   extraargs=cma=256M video=HDMI-A-1:3840x2160M@30eD
   ```

3. Reboot:
   ```bash
   sudo reboot
   ```

**Important notes**:
- HDMI0 (middle port): works well at 50Hz + audio
- HDMI1 (other port): prefers 60Hz but **no audio**
- The `M` flag forces the mode, `eD` forces activation
- The webcam will stay at 30fps even if the screen is at 50/60Hz

### Disable HDMI audio hotplug recovery

If there's an issue with automatic detection:

```bash
sudo rm /etc/udev/rules.d/98-hdmi-audio-recovery.rules
sudo udevadm control --reload-rules
```

## Troubleshooting

### No video

1. Check that the webcam is detected:
   ```bash
   ls -l /dev/video*
   v4l2-ctl --list-devices
   ```

2. Check the service status:
   ```bash
   sudo systemctl status webcam-hdmi-converter-kms
   tail /var/log/webcam-hdmi-converter.log
   ```

3. Check which HDMI port is being used (should be HDMI0 at 1080p50)

### No audio

1. Check that the webcam has a microphone:
   ```bash
   arecord -l | grep -i usb
   ```

2. Check that the HDMI cable is on **HDMI0** (middle port)

3. Test HDMI audio manually:
   ```bash
   speaker-test -D hw:1,0 -c 2 -t sine -f 440 -l 1
   ```

4. If no audio after HDMI unplug: **wait 3-4 seconds** (automatic recovery)

### Audio lost after HDMI unplug

**Normal**: The system automatically restarts in 3-4 seconds via udev.

If it doesn't work:
- Check logs: `dmesg | grep -i hdmi`
- Check udev: `udevadm monitor --property --subsystem-match=drm`
- Manual restart: `sudo systemctl restart webcam-hdmi-converter-kms`

### Stuttering video (judder/tearing)

**Normal**: 30fps webcam → 50Hz screen = slight natural mismatch.

This tearing is:
- Very minimal visually
- Minimal visible impact for most use cases
- Impossible to eliminate without GPU (hardware limitation)

## 📋 Main Files

- **webcam-display-kms.sh** - Main GStreamer script + monitoring
- **webcam-hdmi-converter-kms.service** - systemd service
- **99-webcam-hotplug.rules** - USB webcam hotplug udev rules
- **98-hdmi-audio-recovery.rules** - HDMI hotplug udev rules (audio recovery)
- **install.sh** - Automatic installation
- **uninstall.sh** - Uninstallation

## 📚 Documentation

- [README-KMS.md](README-KMS.md) - GStreamer/KMS technical architecture
- [AUDIO-SUPPORT.md](AUDIO-SUPPORT.md) - Detailed audio configuration
- [HDMI-1080p50-CONFIG.md](HDMI-1080p50-CONFIG.md) - Force HDMI resolution

## ⚙️ System Configuration

### HDMI Resolution

Default: **1920x1080@50Hz** (progressive, not interlaced)

Configured in `/boot/armbianEnv.txt`:
```
extraargs=cma=256M video=HDMI-A-1:1920x1080M@50eD
```

The `M` flag forces the mode, `eD` forces activation.

### Audio

- **Input**: USB webcam mic auto-detected (typically hw:4,0)
- **Output**: HDMI0 audio (hw:1,0 = rockchip-hdmi0)
- **Latency**: ~20ms (buffer-time=20000µs)
- **Format**: 48kHz stereo

### System Priorities

The service runs with:
- `Nice=-10` (high CPU priority)
- `IOSchedulingClass=realtime` (I/O priority)
- Automatic cleanup of zombie processes

## 💻 Compatibility

### Hardware
- **Tested on**: OrangePi 5 Plus (RK3588, 16GB RAM)
- **OS**: Armbian Bookworm (Debian 12, kernel 6.1.115)
- **UVC Webcams**:
  - HP HD Camera / USB Live camera (tested ✓)
  - Logitech C920/C930 (compatible)
  - Any standard USB Video Class webcam

### Supported webcam formats
- **Video**: MJPEG (preferred), YUYV
- **Audio**: USB Audio Class (built-in mic)
- **Resolutions**: Auto-detection, scaled to 1080p

## 🎛️ Performance

- **Video latency**: ~100-150ms (capture → display)
- **Audio latency**: ~20ms
- **CPU**: 20-30% (1 core RK3588 @ 2.4GHz)
- **RAM**: ~25 MB (service + GStreamer)
- **Tearing**: Minimal (30fps webcam → 50Hz display)

## 🔒 Robustness

### Failure handling
- **GStreamer crash** → Auto restart in 5s (systemd)
- **Webcam unplugged** → Wait + auto restart on reconnection
- **HDMI unplugged** → Auto audio recovery in 3-4s (udev)
- **Power outage** → Logs in RAM (zram), no storage wear

### Resilience tests
✅ Webcam unplug during streaming
✅ HDMI unplug during streaming
✅ Hot reboot
✅ Forced GStreamer crash
✅ Power outage (no corruption)

## 📄 License

MIT License - See [LICENSE](LICENSE)

## 🙏 Credits

Developed by Stéphane Bhiri.

Technical stack:
- GStreamer (multimedia pipeline)
- Linux Framebuffer / DRM-KMS (direct display)
- ALSA (low-latency audio)
- systemd + udev (system management)

## 🐛 Bugs & Support

Open an issue on GitHub: https://github.com/stephanebhiri/webcam-to-hdmi-converter/issues