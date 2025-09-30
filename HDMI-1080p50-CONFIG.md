# Configuration HDMI 1080p50

La sortie HDMI est forcée à **1920x1080@50Hz** de deux manières:

## 1. Paramètre du noyau (permanent)

Fichier: `/boot/armbianEnv.txt`

```
extraargs=cma=256M video=HDMI-A-1:1920x1080@50
```

Ce paramètre force le mode dès le boot du noyau.

## 2. Service systemd (au démarrage)

Service: `force-hdmi-1080p50.service`

Exécute au démarrage:
```bash
echo "1920x1080" > /sys/class/drm/card0-HDMI-A-1/mode
```

## Vérification

Après reboot, vérifier le mode actuel:

```bash
cat /sys/class/drm/card0-HDMI-A-1/mode
```

Devrait afficher: `1920x1080`

## Modes disponibles

Liste des modes supportés par le display:

```bash
cat /sys/class/drm/card0-HDMI-A-1/modes
```

## Changement manuel

Pour changer temporairement (jusqu'au reboot):

```bash
# Lister les modes
cat /sys/class/drm/card0-HDMI-A-1/modes

# Forcer un mode
echo "1920x1080" | sudo tee /sys/class/drm/card0-HDMI-A-1/mode
```

## Framerate

Le `@50` dans le paramètre kernel force 50Hz. Si le display ne supporte pas 50Hz, il fallbackera sur 60Hz ou le mode le plus proche disponible.

Pour forcer 60Hz à la place:
```
video=HDMI-A-1:1920x1080@60
```

## Troubleshooting

Si le HDMI ne fonctionne pas après modification:

1. Éditer `/boot/armbianEnv.txt` et retirer `video=HDMI-A-1:1920x1080@50`
2. Rebooter
3. Le système utilisera le mode auto-détecté

## GStreamer et résolution

Le pipeline GStreamer scale toujours la webcam vers 1920x1080:

```bash
videoscale ! video/x-raw,width=1920,height=1080
```

Cette résolution est ensuite affichée via `fbdevsink` sur le framebuffer, qui s'adapte automatiquement à la résolution HDMI configurée.