# CLAUDE.md - AI Assistant Context

Context file for Claude Code when working with the Nexus automation platform.

## System Overview

**Nexus** is a self-hosted AI content automation platform running 24/7 on a Raspberry Pi 4. The system generates, renders, and publishes social media content using n8n workflow automation, AI APIs (Groq, Gemini), and Python image composition.

**Current Production System:** FactsMind carousel generator
- Platform: Instagram (1-3 posts/day)
- Content: 5-slide educational carousels (science, psychology, tech, history, space)
- Pipeline: Groq (fact generation) → Gemini (content expansion + AI images) → Python/Pillow (carousel composition) → Telegram (manual approval) → Manual Instagram upload
- Status: Fully operational, generating daily content

**Infrastructure:**
- Raspberry Pi 4 (4GB RAM, 2GB swap)
- Ubuntu Server 22.04 LTS
- 6 Docker containers (n8n, PostgreSQL, Redis, code-server, Netdata, Watchtower)
- Tailscale network for secure remote access
- Automated backups (config-based, not full disk images)

---

## Working Environment (CRITICAL)

**Two-System Setup:**

```
┌─────────────────────────────────────┐
│ Your PC (Windows + WSL2)            │
│ /home/dvayr/Projects_linux/nexus/   │  ← Edit files here
│                                     │
│ ↓ SSH via ~/ssh-nexus wrapper      │
│                                     │
└─────────────────────────────────────┘
              ↓ Tailscale
┌─────────────────────────────────────┐
│ Raspberry Pi @ 100.122.207.23       │
│ All services run here               │  ← Execute commands here
│ Docker containers, n8n workflows    │
└─────────────────────────────────────┘
```

### SSH Access (for all Pi commands)

**From WSL2, ALWAYS use the wrapper:**
```bash
~/ssh-nexus 'docker ps'
~/ssh-nexus 'sudo systemctl restart smbd'
~/ssh-nexus 'cat /srv/docker/docker-compose.yml'
```

**The wrapper handles:** WSL2 → PowerShell → SSH → Tailscale connectivity with proper path escaping and warning suppression.

### File Access (primary method: Samba)

**Map these network shares in Windows:**
- `\\100.122.207.23\nexus-docker` → `/srv/docker/` (docker-compose.yml, Dockerfiles)
- `\\100.122.207.23\nexus-projects` → `/srv/projects/` (faceless_prod scripts/templates)
- `\\100.122.207.23\nexus-scripts` → `/srv/scripts/` (backup scripts)
- `\\100.122.207.23\nexus-outputs` → `/srv/outputs/` (generated carousels)

**Workflow:**
1. Edit files via Samba shares (use Windows apps, VS Code, etc.)
2. Restart services via SSH: `~/ssh-nexus 'cd /srv/docker && sudo docker compose up -d'`
3. Check logs via SSH: `~/ssh-nexus 'sudo docker logs nexus-n8n --tail 50'`

**Alternative:** Copy files via SSH
```bash
~/ssh-nexus 'cat > /srv/docker/file.yml' < local_file.yml
```

### Web Access (from browser on your PC)

- **n8n:** http://100.122.207.23:5678 (workflow editor)
- **Netdata:** http://100.122.207.23:19999 (system monitoring)
- **code-server:** http://100.122.207.23:8080 (web IDE)

---

## Architecture Quick Reference

### Hardware & Disks

**Raspberry Pi 4:**
- 4GB RAM + 2GB swap (swappiness=10)
- **CRITICAL:** Disk labels are confusing!
  - `/dev/sdb` = System disk (465GB SSD at `/`)
  - `/dev/sda` = Backup disk (465GB SSD at `/mnt/backup`)

### Docker Services

| Container | Port | Purpose |
|-----------|------|---------|
| nexus-n8n | 5678 | Workflow automation (custom image: Python3 + Pillow) |
| nexus-postgres | 5432 | Database (n8n workflows, credentials) |
| nexus-redis | 6379 | Queue for n8n executions |
| nexus-code-server | 8080 | Web-based IDE |
| nexus-netdata | 19999 | System monitoring |
| nexus-watchtower | - | Auto-update containers |

**n8n custom features:**
- Python 3.12 + Pillow 11.2 installed for image composition
- Task runners enabled (port 5679)
- Environment variable access allowed for API keys

### Critical Directory Structure

**On the Pi (`/srv/`):**
```
/srv/
├── docker/
│   ├── docker-compose.yml          # Stack definition
│   └── n8n.Dockerfile              # Custom n8n image with Python
├── projects/
│   ├── faceless_prod/
│   │   ├── factsmind_workflow.json # n8n workflow export
│   │   ├── scripts/composite.py    # Python carousel composition
│   │   └── templates/              # Figma template PNGs (2160x2700)
│   └── nexus/                      # Git repo clone
├── outputs/
│   └── final/                      # Generated carousel slides
└── scripts/
    ├── backup_sync.sh              # Comprehensive config backup
    ├── pg_backup.sh                # PostgreSQL dump
    └── dd_full_image.sh            # Full image (disabled)
```

**Docker volumes (managed):**
- `docker_n8n_data` → n8n workflows and credentials
- `docker_postgres_data` → PostgreSQL database
- `docker_redis_data` → Redis persistence

**Volume mounts (in n8n container):**
- `/data/outputs` → `/srv/outputs`
- `/data/scripts` → `/srv/projects/faceless_prod/scripts`
- `/data/templates` → `/srv/projects/faceless_prod/templates`

---

## FactsMind Carousel Pipeline

**Complete workflow (n8n orchestration):**

```
1. Schedule Trigger (1-3x daily)
   ↓
2. Groq API: Generate 5 mind-blowing facts
   ↓
3. For each fact:
   - Gemini: Expand into hook/body/CTA
   - Gemini: Generate AI image (slides 1-4 only)
   - Write image to /data/outputs/slide_N.png
   ↓
4. Python Execute Command (for each slide):
   python3 /data/scripts/composite.py <slide_num> <type> "<title>" "<subtitle>"
   ↓
5. Composite script (composite.py):
   - Load Figma template PNG (2160x2700px)
   - Paste AI image with aspect ratio preservation (center crop)
   - Render text overlays (180pt title, 85pt subtitle)
   - Save to /data/outputs/final/slide_N_final.png
   ↓
6. Telegram: Send carousel for manual approval
   ↓
7. Manual: Download from Samba share, upload to Instagram
```

**Template types:**
- `template_hook_question.png` - Slide 1 (hook with question)
- `template_progressive_reveal.png` - Slides 2-4 (body content)
- `template_call_to_action.png` - Slide 5 (CTA + branding)

**Image specifications:**
- Canvas: 2160x2700px (Instagram carousel optimal)
- AI images: 1024x1024 → smart crop to 2160x1760
- Fonts: DejaVuSans-Bold (180pt), DejaVuSans (85pt)
- Text positioning: Y=1950 (title), Y=2200 (subtitle)

---

## Important Gotchas

### Path Conventions
- ✅ **Always use `/data/` paths inside n8n** (volume mounts)
- ❌ Never use `/tmp/` (not persistent across container restarts)
- Example: `/data/outputs/slide_1.png` not `/tmp/slide_1.png`

### Disk Confusion
- `/dev/sda` = BACKUP disk (not system!)
- `/dev/sdb` = SYSTEM disk (not backup!)
- This is backwards from typical convention

### File Transfers
- **Primary:** Edit via Samba shares (user-friendly, persistent)
- **Alternative:** SSH copy with heredoc for complex files
- **Restart required:** After editing docker-compose.yml or scripts

### Python in n8n
- n8n container has Python 3.12 + Pillow pre-installed
- No need for separate Python container
- Execute via: `python3 /data/scripts/script.py args`

---

## Backup Strategy

**Automated (systemd timers, daily at 00:00):**
- `file-backup.timer` → Comprehensive config backup (n8n volumes, systemd units, SSH config, home dir, package lists)
- `pg-backup.timer` → PostgreSQL dumps (30-day retention)

**What's backed up:**
- ✅ All `/srv/` application files
- ✅ n8n workflows & credentials (Docker volume)
- ✅ PostgreSQL database (SQL dumps)
- ✅ Systemd units, SSH config, Docker config
- ✅ User home directory, package lists

**What's NOT backed up (requires manual reinstall):**
- ❌ Base OS (Raspberry Pi OS)
- ❌ Docker engine
- ❌ APT packages (list exported for easy reinstall)

**Backup location:** `/mnt/backup/` (458GB, 1% used after removing full disk images)

**Restore instructions:** See `/mnt/backup/RESTORE_INSTRUCTIONS.md` or `docs/operations/maintenance.md`

---

## Common Commands

### Docker Management
```bash
# View all containers
~/ssh-nexus 'sudo docker ps'

# Restart n8n after config change
~/ssh-nexus 'cd /srv/docker && sudo docker compose up -d n8n'

# View n8n logs
~/ssh-nexus 'sudo docker logs nexus-n8n --tail 50'

# Rebuild custom n8n image (after Dockerfile change)
~/ssh-nexus 'cd /srv/docker && sudo docker compose build n8n && sudo docker compose up -d n8n'
```

### System Monitoring
```bash
# Check system health
~/ssh-nexus 'free -h && df -h && vcgencmd measure_temp'

# View Netdata (browser): http://100.122.207.23:19999

# Check backup timers
~/ssh-nexus 'systemctl list-timers backup*.timer pg-backup.timer'
```

### Backup Operations
```bash
# Manual backup run
~/ssh-nexus '/srv/scripts/backup_sync.sh'
~/ssh-nexus '/srv/scripts/pg_backup.sh'

# Check backup disk space
~/ssh-nexus 'df -h /mnt/backup'

# View backup contents
~/ssh-nexus 'ls -lh /mnt/backup/docker-volumes/n8n_data/'
```

---

## Documentation Map

**Quick references (this file):**
- Current operational state
- FactsMind workflow
- Critical gotchas

**Detailed documentation:**
- **Setup:** `docs/setup/quickstart.md` - Complete Pi setup from scratch
- **FactsMind project:** `docs/projects/factsmind.md` - Build log and implementation details
- **Maintenance:** `docs/operations/maintenance.md` - Backup/restore procedures, troubleshooting
- **Architecture:** `docs/architecture/system-reference.md` - Deep technical reference
- **Gemini context:** `docs/ai-context/gemini.md` - Instructions for Google Gemini

**Root README:** `/README.md` - Project overview and quick links

---

## Development Notes

**Git workflow:**
- Commits use conventional format: `feat:`, `fix:`, `refactor:`, etc.
- Include `🤖 Generated with Claude Code` in commit messages
- `Co-Authored-By: Claude <noreply@anthropic.com>`

**File naming:**
- Python/scripts: `snake_case.py`
- Branches: `kebab-case`
- Dockerfiles: `PascalCase.Dockerfile`

**Testing:**
- No formal test suite currently
- Manual testing via n8n workflow execution
- Schema validation in `schemas/carousel_manifest.schema.json`
