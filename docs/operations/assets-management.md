# Asset Management and Network Access

**Version:** 1.0
**Last Updated:** 2025-11-20
**Maintainer:** didac

---

## Overview

This document describes the permanent asset storage structure for FactsMind content and how to access these assets remotely via Samba network shares.

## Asset Directory Structure

All permanent assets are stored in `/srv/projects/factsmind/assets/` on the Pi and mounted as `/data/assets/` inside containers.

```
/srv/projects/factsmind/assets/
├── audio/          # Permanent audio files (intro music, sound effects)
├── fonts/          # Typography files
│   ├── Montserrat-ExtraBold.ttf    (445KB)
│   ├── Montserrat-Regular.ttf      (436KB)
│   ├── Montserrat-SemiBold.ttf     (445KB)
│   ├── Poppins-Bold.ttf            (153KB)
│   └── Poppins-Medium.ttf          (155KB)
├── images/         # Permanent images (backgrounds, overlays)
└── logos/          # Brand assets (8.7MB total)
    ├── FACTSMIND style guide.png   (2.1MB)
    ├── factsmind_logo.png          (1.4MB)
    ├── factsmind_logo_background.png (952KB)
    ├── factsmind_logo_dark.png     (1.4MB)
    ├── factsmind_logo_text.png     (1.2MB)
    ├── factsmind_style_guide.md    (370B)
    └── slide_5_background.png      (1.7MB)
```

## Path Mappings

### On Host (Nexus Pi)
- **Host path:** `/srv/projects/factsmind/assets/`
- **Owner:** `didac:didac`
- **Permissions:** `0775` (directories), `0664` (files)

### Inside n8n Container
- **Container path:** `/data/assets/`
- **Access user:** `node` (UID 1000, GID 1003)
- **Mounted read-write:** Yes

### Used by Scripts
- **composite.py:** Uses `/data/assets/fonts/` for typography
- **audio_mastering.py:** Can reference `/data/assets/audio/` for intros
- **n8n workflows:** Reference as `/data/assets/<subdirectory>/<filename>`

## Samba Network Access

### Connection Details

**Share Name:** `factsmind-assets`
**Network Path:** `\\100.122.207.23\factsmind-assets`
**Username:** `didac`
**Protocol:** SMB/CIFS

### Connection Instructions

#### Windows
1. Open File Explorer
2. In the address bar, type: `\\100.122.207.23\factsmind-assets`
3. Enter credentials when prompted:
   - Username: `didac`
   - Password: [your didac user password]
4. Right-click on the share and select "Map network drive" for permanent access

#### macOS
1. In Finder, press `Cmd+K`
2. Enter server address: `smb://100.122.207.23/factsmind-assets`
3. Click Connect
4. Select "Registered User" and enter:
   - Username: `didac`
   - Password: [your didac user password]
5. Click "Connect"

#### Linux
```bash
# Install cifs-utils if not present
sudo apt install cifs-utils

# Create mount point
sudo mkdir -p /mnt/factsmind-assets

# Mount temporarily
sudo mount -t cifs //100.122.207.23/factsmind-assets /mnt/factsmind-assets -o username=didac

# Or add to /etc/fstab for permanent mount
echo "//100.122.207.23/factsmind-assets /mnt/factsmind-assets cifs username=didac,uid=1000,gid=1000,nofail 0 0" | sudo tee -a /etc/fstab
```

### Available Samba Shares

| Share Name | Path | Purpose |
|------------|------|---------|
| `factsmind-assets` | `/srv/projects/factsmind/assets` | Permanent FactsMind assets |
| `nexus-backup` | `/mnt/backup` | Backup storage access |
| `nexus-home` | `/home` | User home directories |
| `nexus-docker` | `/srv/docker` | Docker configurations |
| `nexus-scripts` | `/srv/scripts` | System scripts |

### Security Notes

- Samba access is restricted to user `didac` only
- Access over Tailscale VPN recommended for security
- File creation mask: `0664` (rw-rw-r--)
- Directory creation mask: `0775` (rwxrwxr-x)
- Read-write access enabled for authorized user

## Usage Workflows

### Adding a New Logo
1. Connect to `\\100.122.207.23\factsmind-assets` via Samba
2. Navigate to `logos/` folder
3. Copy your logo file (PNG, SVG, JPG supported)
4. The file is immediately accessible from n8n workflows at `/data/assets/logos/your-file.png`

### Adding Background Music
1. Connect to Samba share
2. Navigate to `audio/` folder
3. Copy your audio file (MP3, WAV supported)
4. Reference in n8n workflow as `/data/assets/audio/your-music.mp3`

### Adding New Fonts
1. Connect to Samba share
2. Navigate to `fonts/` folder
3. Copy TTF/OTF font files
4. Update `composite.py` or other scripts to reference: `/data/assets/fonts/YourFont.ttf`

### Adding Permanent Images
1. Connect to Samba share
2. Navigate to `images/` folder
3. Copy image files
4. Reference in workflows as `/data/assets/images/your-image.png`

## Backup Policy

The assets folder is included in the standard backup routine:

- **Daily incremental:** rsync to `/mnt/backup/daily/<date>/`
- **Full image backup:** Weekly dd image includes assets
- **Offsite sync:** Assets synced to cloud backup via rclone (if configured)

## Troubleshooting

### Cannot Connect to Samba Share

```bash
# On Pi - check if Samba service is running
ssh didac@100.122.207.23
sudo systemctl status smbd

# Restart Samba if needed
sudo systemctl restart smbd

# Check if firewall is blocking (should not be on default Pi setup)
sudo ufw status
```

### Permission Denied When Writing

```bash
# On Pi - fix ownership
ssh didac@100.122.207.23
sudo chown -R didac:didac /srv/projects/factsmind/assets/
sudo chmod -R 775 /srv/projects/factsmind/assets/
```

### Files Not Visible in Container

```bash
# On Pi - check mount inside container
docker exec nexus-n8n ls -la /data/assets/

# If empty, recreate container with correct volume mounts
cd /srv/projects/nexus/infra
git pull
docker compose up -d --force-recreate n8n
```

## Docker Compose Configuration

Assets are mounted in `docker-compose.yml`:

```yaml
services:
  n8n:
    volumes:
      - /srv/projects/factsmind/assets:/data/assets
```

## Related Documentation

- [System Reference](../architecture/system-reference.md) - Overall system architecture
- [Maintenance Guide](maintenance.md) - Backup and restore procedures
- [Quick Start Guide](../setup/quickstart.md) - Initial system setup

## Changelog

- **2025-11-20:** Initial creation. Added Samba share configuration and asset structure documentation.
