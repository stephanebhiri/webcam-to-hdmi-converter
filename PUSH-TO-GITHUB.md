# Instructions pour pusher sur GitHub

## Étape 1: Créer le repo sur GitHub

1. Aller sur https://github.com/stephanebhiri
2. Cliquer sur "New repository"
3. Nom du repo: **webcam-hdmi-converter**
4. Description: `Webcam to HDMI converter for OrangePi 5 Plus using GStreamer + Linux Framebuffer`
5. Public
6. **NE PAS** initialiser avec README, .gitignore ou license (déjà créés)
7. Cliquer "Create repository"

## Étape 2: Pusher le code

Une fois le repo créé, exécuter ces commandes:

```bash
cd ~/webcam-hdmi-converter

# Ajouter le remote
git remote add origin https://github.com/stephanebhiri/webcam-hdmi-converter.git

# Pousser le code
git push -u origin main
```

GitHub va demander tes identifiants:
- Username: `stephanebhiri`
- Password: Utiliser un **Personal Access Token** (pas ton mot de passe)

## Créer un Personal Access Token (si nécessaire)

1. Aller sur https://github.com/settings/tokens
2. "Generate new token" → "Generate new token (classic)"
3. Note: `OrangePi webcam-hdmi-converter`
4. Scopes: Cocher `repo` (toutes les cases)
5. "Generate token"
6. Copier le token (il ne sera affiché qu'une fois!)
7. Utiliser ce token comme mot de passe lors du push

## Alternative: SSH

Si tu préfères SSH:

```bash
# Générer une clé SSH (si pas déjà fait)
ssh-keygen -t ed25519 -C "stephane@bhiri.fr"

# Copier la clé publique
cat ~/.ssh/id_ed25519.pub

# Ajouter la clé sur GitHub:
# https://github.com/settings/ssh/new

# Changer le remote en SSH
git remote set-url origin git@github.com:stephanebhiri/webcam-hdmi-converter.git

# Pousser
git push -u origin main
```

## Vérification

Une fois pushé, vérifier sur:
https://github.com/stephanebhiri/webcam-hdmi-converter

Le README avec les emojis devrait s'afficher directement!