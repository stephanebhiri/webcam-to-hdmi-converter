# Support Audio - Webcam vers HDMI

## Fonctionnement

Le script détecte automatiquement si la webcam a un microphone intégré:

- ✅ **Micro détecté** → Audio capturé et envoyé vers sortie HDMI
- ❌ **Pas de micro** → Vidéo uniquement (mode actuel)

## Pipeline GStreamer avec Audio

Quand une webcam avec micro est détectée:

```
[Vidéo]                              [Audio]
webcam → v4l2src                     webcam mic → alsasrc
    ↓                                    ↓
jpegdec                              audioconvert
    ↓                                    ↓
videoconvert                         audioresample (48kHz, 2ch)
    ↓                                    ↓
videoscale (1080p)                   queue
    ↓                                    ↓
fbdevsink (/dev/fb0)                 alsasink (HDMI audio)
    ↓                                    ↓
  HDMI Vidéo                         HDMI Audio
```

## Sortie Audio HDMI

Device audio utilisé: **hw:1,0** (rockchip-hdmi0)

Vérifier les devices audio:
```bash
aplay -l    # Sorties audio
arecord -l  # Entrées audio (webcam)
```

## Tester avec une Webcam avec Micro

1. Brancher une webcam avec microphone intégré
2. Le service détectera automatiquement le micro
3. Les logs afficheront:
   ```
   Found potential audio device: hw:X,0
   Starting pipeline with audio from hw:X,0
   ```

## Test Manuel Audio

Pour tester si une webcam a un micro:

```bash
# Lister les périphériques de capture
arecord -l

# Tester capture audio
arecord -D hw:X,0 -f S16_LE -r 48000 -c 2 -d 5 test.wav

# Écouter l'enregistrement
aplay test.wav
```

## Test Pipeline GStreamer avec Audio

```bash
gst-launch-1.0 \
  v4l2src device=/dev/video0 \
  ! jpegdec ! videoconvert ! videoscale \
  ! video/x-raw,width=1920,height=1080 \
  ! fbdevsink device=/dev/fb0 \
  alsasrc device=hw:4,0 \
  ! audioconvert ! audioresample \
  ! audio/x-raw,rate=48000,channels=2 \
  ! alsasink device=hw:1,0
```

## Latence Audio

- **Latence typique**: 50-150ms
- **Causes**: Buffering ALSA + conversion + réseau USB
- **Pour réduire**: Ajuster les buffers ALSA (avancé)

## Troubleshooting

### Pas de son malgré webcam avec micro

1. Vérifier que la webcam apparaît dans `arecord -l`
2. Vérifier les logs:
   ```bash
   sudo journalctl -u webcam-hdmi-converter-kms -f
   ```
3. Tester manuellement avec `arecord`

### Son déformé ou crackling

Le buffer audio est peut-être trop petit. Modifier le pipeline dans `webcam-display-kms.sh`:

```bash
! queue max-size-buffers=0 max-size-time=0 max-size-bytes=0 \
! alsasink device=hw:1,0 buffer-time=200000
```

### Désynchronisation audio/vidéo

C'est normal avec un léger décalage (50-200ms). Pour améliorer:
- Utiliser `sync=true` sur fbdevsink (mais peut causer des saccades)
- Réduire la résolution webcam

## Configuration Avancée

### Changer la sortie audio (pas HDMI)

Modifier dans `webcam-display-kms.sh` ligne 139:
```bash
! alsasink device=hw:1,0    # hw:CARD,DEVICE
```

Exemples:
- `hw:0,0` - DisplayPort audio
- `hw:2,0` - HDMI-1 alternatif
- `hw:3,0` - Codec audio interne (ES8388)

### Format audio

Actuellement: **48kHz, stéréo, 16-bit**

Pour changer (ligne 137):
```bash
! audio/x-raw,rate=44100,channels=1    # 44.1kHz mono
```

## État Actuel

Ta webcam **HP HD Camera** n'a pas de microphone → Mode vidéo uniquement.

Avec une webcam avec micro (ex: Logitech C920), l'audio sera automatiquement activé.