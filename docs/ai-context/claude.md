# CLAUDE.md - AI Assistant Context

Context file for Claude Code when working with the Nexus automation platform.

## System Overview

**Nexus** is a self-hosted AI content automation platform running 24/7 on a Raspberry Pi 4. The system generates, renders, and publishes social media content using n8n workflow automation, AI APIs (Groq, Gemini), and Python image composition.

**Current Production System:** FactsMind carousel generator
- Platform: Instagram (1-3 posts/day)
- Content: 5-slide educational carousels (science, psychology, tech, history, space) + Story background
- Pipeline: Gemini (fact + content generation + AI images) → Python/Pillow (pure Python composition) → Telegram delivery
- Status: ✅ Production ready with complete visual polish (Nov 2025)
- Repository: https://github.com/dvayreda/factsmind (separate from Nexus)

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
- `\\100.122.207.23\nexus-projects` → `/srv/projects/` (factsmind application files)
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

## n8n MCP Integration (Optional)

**Model Context Protocol** enables Claude Code to interact directly with n8n workflows via API.

**Setup required:** Configure `claude_desktop_config.json` on Windows with n8n MCP server
**Documentation:** See `docs/operations/n8n-mcp-setup.md` for complete setup instructions

**When configured, enables:**
- Reading workflow structure and node configurations
- Modifying workflows via conversation
- Creating new workflows with AI assistance
- Accessing documentation for 543 n8n nodes
- Debugging workflow issues with full context

**API credentials:**
- n8n API key generated via web UI (http://100.122.207.23:5678)
- API endpoint: http://100.122.207.23:5678/api/v1/

**Status:** Setup instructions available, not yet configured in this session

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
│   ├── factsmind/                  # FactsMind application (separate repo)
│   │   ├── scripts/                # composite.py, factsmind_logo.png
│   │   ├── assets/fonts/           # Montserrat typography
│   │   └── docs/                   # Project documentation
│   ├── faceless_prod -> factsmind  # Backward compatibility symlink
│   ├── faceless_prod.OLD/          # Archived (remove after 1 week)
│   └── nexus/                      # Nexus git repo clone
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
- `/data/outputs` → `/srv/outputs` (AI images + final composites)
- `/data/scripts` → `/srv/projects/factsmind/scripts` (composite.py, factsmind_logo.png)
- `/data/fonts` → `/srv/projects/factsmind/assets/fonts` (Montserrat typography)

---

## FactsMind Carousel Pipeline

**Complete workflow (n8n orchestration):**

```
1. Manual Trigger (Execute workflow button)
   ↓
2. Get Topic → Topic Generator (Parse input)
   ↓
3. Fact Generator (Gemini): Generate verified fact
   ↓
4. Content Engine (Gemini): Generate complete carousel JSON
   - 4 slides (1 hook + 3 reveals)
   - Image prompts per slide
   - Visual keywords, hashtags, captions
   ↓
5. Image Prompt Optimizer (Code node): Enhance prompts with brand guidelines
   ↓
6. [4 PARALLEL PATHS - Slides 1-4]
   Each path:
   - Gemini Image: Generate 1024x1024 AI image
   - Write File: Save to /data/outputs/slide_N.png
   - Code: Build composite.py command with proper escaping
   - Execute Command: python3 /data/scripts/composite.py ...
   ↓
7. Composite script (composite.py) - PURE PYTHON GENERATION:
   - Create dark navy background with subtle purple gradient
   - Load and resize AI image (vignette + fade effects)
   - Draw divider with FactsMind logo (spherical halo effect)
   - Render title text (Montserrat ExtraBold, 65px/110px)
   - Render subtitle text (Montserrat Regular, 40px)
   - Add text shadows (ALL text for readability)
   - Add SWIPE indicator (cyan glow, 32px)
   - Save to /data/outputs/final/slide_N_final.png
   ↓
8. Manual: Download from Samba share, upload to Instagram
```

**NO TEMPLATES - Pure Python generation!**

**Visual specifications (FactsMind Official Style Guide):**
- **Canvas:** 1080x1350px (Instagram native resolution)
- **Background:** Dark navy (#020308) + subtle purple gradient (bottom 20%)
- **Fonts:** Montserrat ExtraBold/Regular/SemiBold
  - Hook: 110px
  - Title: 65px
  - Subtitle: 40px
  - SWIPE: 32px (cyan glow)
- **Colors:**
  - Text: Soft White (#E8E8E8)
  - Accents: Cyan Glow (#75E8FF)
  - Divider: Cyan Glow (#75E8FF)
- **Visual Effects:**
  - Text shadows: 3px offset, 12px blur, 70% opacity
  - Image vignette: 30% strength
  - Image fade: Y=700 → transparent
  - Logo halo: 80px spherical black gradient

---

## Important Gotchas

### Path Conventions
- ✅ **Always use `/data/` paths inside n8n** (volume mounts)
- ❌ Never use `/tmp/` (not persistent across container restarts)
- Example: `/data/outputs/slide_1.png` not `/tmp/slide_1.png`

### Image Transfer & 400 Error Fix (CRITICAL)
**NEVER use `cat` over SSH for binary image files!**

❌ **Wrong (corrupts images, causes 400 errors):**
```bash
~/ssh-nexus 'cat /srv/outputs/slide.png > /tmp/slide.png'
# Result: "Could not process image" API 400 error
# File shows as "data" instead of "PNG image data"
```

✅ **Correct (preserves binary data):**
```bash
scp didac@100.122.207.23:/srv/outputs/slide.png /tmp/slide.png
# Or access via Samba: \\100.122.207.23\nexus-outputs\
```

**Why:** `cat` treats binary files as text over SSH pipes, corrupting the image data.

### n8n Workflow Interactions
- ❌ **Don't read workflow JSON files** (FactsMindFlow from gpt.json, etc.) - triggers n8n API errors
- ❌ **Don't try to programmatically deploy workflows** - use n8n UI only
- ✅ **Only manage Python scripts, fonts, and output files**
- ✅ **Let user handle all workflow changes via n8n web UI**

### Disk Confusion
- `/dev/sda` = BACKUP disk (not system!)
- `/dev/sdb` = SYSTEM disk (not backup!)
- This is backwards from typical convention

### File Transfers
- **Primary:** Edit via Samba shares (user-friendly, persistent)
- **Alternative:** SSH copy with `scp` for binary files
- **Never:** `cat` over SSH for images/binaries
- **Restart required:** After editing docker-compose.yml or scripts

### Python in n8n
- n8n container has Python 3.12 + Pillow 11.0 pre-installed
- Montserrat fonts mounted at /data/fonts/
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

## Helper Scripts (Token Optimizers)

These scripts reduce token usage by 60-70% by consolidating multi-command operations into single commands.

**On the Pi (`~/`):**
- `nexus-quick.sh` - Ultra-fast health check (containers, RAM, disk, temp, errors) [MOST USED]
- `nexus-health.sh` - Comprehensive system status
- `nexus-n8n-status.sh` - n8n workflow debugging
- `nexus-backup-status.sh` - Backup status and history
- `nexus-carousel-recent.sh` - Recent carousel outputs
- `nexus-logs.sh <service> [lines]` - Smart log viewer
- `nexus-restart.sh <service>` - Restart and verify
- `nexus-cleanup.sh` - Free up disk space
- `nexus-compare.sh snapshot|diff` - Before/after comparison
- `nexus-find.sh <keyword>` - Quick file search

**On WSL2 (local):**
- `nexus-git-push "message"` - Automated git workflow
- `nexus-deploy <file> <remote> <service>` - Deploy and restart

**Quick examples:**
```bash
# Start of session
~/ssh-nexus '~/nexus-quick.sh'

# After changes
nexus-deploy infra/docker-compose.yml /srv/docker/docker-compose.yml n8n
nexus-git-push "fix: Update config"

# Debugging
~/ssh-nexus '~/nexus-health.sh'
~/ssh-nexus '~/nexus-n8n-status.sh'
```

**Full documentation:** See `scripts/README.md` for detailed usage and examples.

---

## Common Commands (Fallback)

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
- **FactsMind project:** https://github.com/dvayreda/factsmind - Separate repository with implementation details
- **Maintenance:** `docs/operations/maintenance.md` - Backup/restore procedures, troubleshooting
- **Architecture:** `docs/architecture/system-reference.md` - Deep technical reference
- **Migration:** `MIGRATION_GUIDE.md` - Repository split documentation (Nov 2025)

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
- Formal test suite using pytest (see `tests/` directory)
- Test coverage reporting with pytest-cov (80% minimum required)
- Manual testing via n8n workflow execution for integration tests
