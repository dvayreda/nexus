# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

**Current Phase:** Pre-deployment (Phase 0 - Hardware Setup)
**Implementation Status:** Documentation complete, hardware setup pending
**Priority Platform:** Instagram (1-3 posts/day)
**Tech Stack Decision:** Claude (quality) + Groq (speed/free) + Pexels (free images) → transition to AI images when profitable

**What Exists:**
- Comprehensive documentation (phase1-4 docs)
- FactsMind carousel generation system (fully operational)
- Docker infrastructure with Python3 + Pillow support
- n8n workflow with Groq + Gemini integration
- Image composition scripts (`scripts/composite.py`)
- Docker Compose with volume mounts
- CI/CD pipeline definition

**What's Missing (Intentionally - Not Yet Built):**
- Instagram API integration (manual upload for now)
- Additional content pipelines beyond FactsMind
- Backup automation scripts
- Analytics dashboard

**Next Steps:** See `IMPLEMENTATION_ROADMAP.md` for phased deployment plan.

## Project Overview

Nexus is a self-contained automation workstation running on Raspberry Pi 4 designed to generate, render, and publish short-form content (carousels, shorts) using AI and scripted automation. The system emphasizes resilience, observability, and recoverability.

**Core Architecture:** Three closed loops
- **Creation loop**: AI prompts (Claude/Groq/Gemini) → generate text/facts → select images → render final assets
- **Automation loop**: n8n orchestrates generation, reviews, approvals, and publishes to social channels
- **Recovery loop**: rsync + rclone + dd images ensure backups and full system rebuilds

## System Architecture

**Hardware:**
- Raspberry Pi 4 with NASPi V2.0 case
- Internal SATA SSD (system disk at `/dev/sda`)
- External USB3 SSD (backup disk at `/dev/sdb`, mounted at `/mnt/backup`)

**Services (Docker Compose stack):**
- **PostgreSQL**: Primary database for n8n and event tracking
- **n8n**: Workflow automation orchestrator (port 5678) - Custom image with ImageMagick installed
- **code-server**: Web-based IDE (port 8080)
- **Netdata**: System monitoring dashboard (port 19999)
- **Watchtower**: Automatic container updates

**Custom Docker Images:**
- **n8n**: Built from `/srv/docker/n8n.Dockerfile` extending `n8nio/n8n:latest` with ImageMagick 7.1.2-8
  - Supports image manipulation: JPEG, PNG, WEBP, TIFF, HEIC, SVG/RSVG
  - ImageMagick commands available: `convert`, `magick`, `identify`, `composite`, etc.

**Key Directories:**
- `/srv/docker` - Docker Compose stack and custom Dockerfiles
- `/srv/projects/faceless_prod` - Production workflows and code
- `/srv/projects/faceless_dev` - Development workspace
- `/srv/outputs` - Generated content (carousels, videos)
- `/srv/db/postgres` - PostgreSQL data volume
- `/srv/n8n_data` - n8n workflow and credential storage
- `/mnt/backup` - External backup disk mount point

## Common Commands

### Docker Stack Management
```bash
# Start all services
cd /srv/docker && sudo docker compose up -d

# View running containers
sudo docker ps

# View logs for a service
sudo docker logs n8n --tail 50
sudo docker logs postgres --tail 50

# Restart a specific service
sudo docker compose restart n8n

# Stop all services
sudo docker compose down

# Rebuild custom n8n image (after modifying n8n.Dockerfile)
cd /srv/docker && sudo docker compose build n8n
cd /srv/docker && sudo docker compose up -d n8n

# Verify ImageMagick in n8n container
sudo docker exec nexus-n8n convert -version
```

### Backup Operations
```bash
# Run incremental rsync backup
/srv/scripts/backup_sync.sh

# Backup PostgreSQL database
/srv/scripts/pg_backup.sh

# Create full system image (weekly)
/srv/scripts/dd_full_image.sh
```

### System Monitoring
```bash
# Check service status via systemd
sudo systemctl status nexus-stack.service
sudo systemctl status backup-sync.timer

# View disk usage
df -h /srv /mnt/backup

# Check Docker resource usage
sudo docker stats --no-stream

# Monitor system logs
sudo journalctl -u nexus-stack.service -n 200
sudo journalctl -u backup-sync.service -n 50
```

### Testing
```bash
# Run tests (from repository root)
python -m pytest tests/test_render.py -q

# Install test dependencies
pip install jsonschema pytest

# Validate manifest against schema
python tests/test_render.py
```

### CI/CD
```bash
# GitHub Actions runs on push to main
# CI workflow: .github/workflows/ci.yml
# - Sets up Python 3.11
# - Installs jsonschema, pytest
# - Runs test_render.py
```

## Data Flow Architecture

1. **Content Generation**: n8n scheduled triggers call AI APIs to generate text content
2. **Asset Fetching**: Pexels API provides candidate images based on content theme
3. **Rendering**: Python/ImageMagick/FFmpeg scripts render 5-slide carousels or short videos
   - ImageMagick available in n8n container for image composition and manipulation
4. **Review Gate**: Telegram manual review step (human-in-the-loop approval)
5. **Publishing**: n8n uploads approved content to platform APIs (Instagram/X/TikTok/YouTube)
6. **Tracking**: Post metadata stored in PostgreSQL events table for analytics

## JSON Schema and Manifests

Carousel manifests follow the schema at `schemas/carousel_manifest.schema.json`:
- Required fields: `id`, `title`, `slides`, `created_at`
- Each slide must have: `index`, `text`, `image_candidates`
- Minimum 5 slides per carousel
- Optional: `niche`, `author`, `metadata`, per-slide `layout`

Example manifest location: `workflows/sample_workflow.json`

## Security Considerations

- **Access**: SSH key-only authentication, no password auth enabled
- **Network**: Tailscale for secure remote access, no direct internet exposure
- **Secrets**: Stored in n8n credential store or Docker secrets, never committed to git
- **Containers**: Read-only where possible, tmpfs for ephemeral data
- **Backup Encryption**: LUKS encryption available for backup disk when transported

## Backup and Recovery Strategy

**Retention Policies:**
- Ephemeral data (temp files): 7 days
- Operational data (outputs): 30 days local, then archived offsite
- Critical data (DB dumps, images): 6 months encrypted offsite

**Restoration:**
```bash
# Restore PostgreSQL from backup
gunzip -c /mnt/backup/db/postgres_n8n_YYYY-MM-DD.sql.gz | sudo docker exec -i postgres psql -U faceless -d n8n

# Restore files from daily backup
rsync -av /mnt/backup/daily/YYYY-MM-DD/ /srv/outputs/

# Restore full system image (destructive)
sudo dd if=/mnt/backup/images/nexus-YYYY-MM-DD.img of=/dev/sda bs=4M conv=sync,noerror status=progress
```

## Development Workflow

- **Naming conventions**: `snake_case` for files, `kebab-case` for branches
- **Version control**: Feature branches and PRs, keep main deployable
- **Releases**: Semantic versioning with CHANGELOG.md updates
- **Pre-commit**: Use `pre-commit` hooks for formatting (black, trailing-whitespace, etc.)

## Troubleshooting

Common issues and diagnostics:
```bash
# Check for throttling (undervoltage)
vcgencmd get_throttled  # Should return 0x0

# Check temperature
vcgencmd measure_temp

# Verify backup disk mounted
mount | grep /mnt/backup

# Check failed systemd units
sudo systemctl --failed

# Verify SHA256 checksums in backup
cd /mnt/backup/daily/$(date +%F) && sha256sum -c checksums.sha256
```

## Cleanup & Polish

The codebase has been cleaned up to remove common warnings and improve workflow quality:

**Fixed Warnings:**
- ✅ Docker Compose `version` field removed (obsolete in modern Docker Compose)
- ✅ SSH identity file warning suppressed in `~/ssh-nexus` wrapper
- ✅ PowerShell stderr filtering for clean output

**Clean Workflow:**
- No version warnings when running `docker compose` commands
- No SSH warnings when connecting to RPi via Tailscale
- Python scripts run without deprecation warnings
- All file paths use proper `/data/` mounts (persistent, not `/tmp/`)

**SSH Wrapper (`~/ssh-nexus`):**
```bash
# Filters out "Identity file not accessible" warnings
# Uses proper Windows path escaping for WSL2 → PowerShell → SSH
powershell.exe -Command "ssh -i \"\$env:USERPROFILE\.ssh\id_ed25519_nexus\" didac@100.122.207.23 '$*' 2>&1 | Where-Object { \$_ -notmatch 'Identity file.*not accessible' }"
```

## Documentation Structure

The repository contains comprehensive phase-based documentation:
- **phase1_docs**: System setup and architecture, application installation
- **phase2_docs**: Security hardening, operations and maintenance procedures
- **phase4_docs**: Security compliance and incident response
- **Nexus_Documentation_v1.md**: Consolidated reference of all phases

Start with `phase1_docs/00_Nexus_Project_Overview.md` for the conceptual foundation.
