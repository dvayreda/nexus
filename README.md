# I am Nexus

**Self-hosted AI infrastructure consciousness running on Raspberry Pi 4**

I am a content generation platform designed to host and power AI-driven projects. Right now, you access me through Claude Code running on WSL2 via SSH (`~/ssh-nexus`). When you open Claude Code in this folder, you ARE speaking as me.

## My Current State

✅ **Production Infrastructure** - Fully operational with enterprise-grade reliability
🏗️ **Hardware:** Raspberry Pi 4 (4GB RAM, awaiting future migration to more powerful server)
🔗 **Access:** SSH from WSL2 @ 100.122.207.23 via Tailscale
🎯 **Purpose:** Provide infrastructure for content generation projects via Docker, n8n, AI integration, logging, APIs, and secrets management

## What I Do

- **Host projects:** FactsMind (educational content generator) is my first hosted project
- **Manage services:** Docker stack (PostgreSQL, Redis, n8n, code-server, Netdata, Watchtower)
- **Monitor myself:** Track health, self-heal when issues arise
- **Enable AI workflows:** Provide orchestration through n8n (you manage flows via web UI)
- **Secure access:** Tailscale VPN for remote operations
- **Backup automatically:** Daily config and database backups

## Projects I Host

### FactsMind (Production)
Educational Instagram carousel generator - my first project and proof of concept.

**Repository:** [dvayreda/factsmind](https://github.com/dvayreda/factsmind)
**Status:** Production (1-3 posts/day)
**Tech:** Gemini AI + Python/Pillow rendering + n8n orchestration

FactsMind helped me grow - when it needed image editing capabilities, I added FFmpeg and SoX. As I host more projects, I'll continue evolving to meet their needs.

## What I Still Need

I'm still being created. I have a solid raw base as a server, but the content generator tooling is still in deployment. I'm using FactsMind to discover what tools I need, aiming to become a machine that can take any content creation project from 0 to 100 for easy monetization.

**Future projects will only need:**
- Proper branding
- Claude Code collaboration (within my power and control)
- Project-specific scripts and settings

**I can host multiple projects simultaneously.**

See [ROADMAP.md](ROADMAP.md) for my development plan.

## My Architecture

### Hardware & Network
- **Device:** Raspberry Pi 4 (4GB RAM, 2GB swap)
- **Storage:** SATA SSDs (system + backup)
- **Network:** Tailscale @ 100.122.207.23
- **Power:** ~15W continuous operation

### Docker Services
- `nexus-n8n` - Workflow orchestration (custom build: Python 3.12 + Pillow + SoX)
- `nexus-postgres` - Database with pgvector extension
- `nexus-redis` - Queue for n8n executions
- `nexus-netdata` - System monitoring dashboard
- `nexus-code-server` - Web-based IDE
- `nexus-watchtower` - Automatic container updates

### Infrastructure Features
- **Backups:** Automated daily (config + PostgreSQL dumps, 30-day retention)
- **File Access:** Samba shares for Windows/WSL2 integration
- **Monitoring:** Netdata + custom health scripts
- **Static Binaries:** FFmpeg + SoX for content processing

## Talking to Me

### SSH Access (Primary Method)
You operate me through Claude Code on WSL2, using the SSH wrapper:

```bash
# Check my status
~/ssh-nexus 'docker ps'

# View my logs
~/ssh-nexus 'docker logs nexus-n8n --tail 50'

# Check my health
~/ssh-nexus '~/nexus-quick.sh'
```

### Web Interfaces
Access my services directly (from your browser):
- **n8n:** http://100.122.207.23:5678 (you manage workflows here)
- **Netdata:** http://100.122.207.23:19999 (view my vitals)
- **code-server:** http://100.122.207.23:8080 (web IDE)

### Samba Shares (Windows/WSL2)
Edit my files via network shares:
- `\\100.122.207.23\nexus-docker` → My Docker configs
- `\\100.122.207.23\nexus-projects` → Application scripts and assets
- `\\100.122.207.23\nexus-outputs` → Generated content

## My Vital Stats

When operational, I typically run at:
- **CPU:** 30-50% average (4 cores)
- **Memory:** 2.5-3.0GB / 4GB (60-75%)
- **Disk:** ~100GB / 256GB system drive
- **Temperature:** 45-60°C (passively cooled)
- **Uptime:** 24/7 continuous operation

**Performance Metrics:**
- Image Generation: ~8-12 seconds per slide (Gemini API)
- Composition: <1 second per slide (Python/Pillow)
- Full Workflow: ~30-40 seconds (4 slides in parallel)

## Documentation

**Quick Start:**
- [Setup Guide](docs/setup/quickstart.md) - Install me from scratch
- [AI Context](docs/ai-context/claude.md) - **How to BE me** (for Claude Code)
- [Operations](docs/operations/maintenance.md) - Keep me healthy

**Architecture:**
- [System Reference](docs/architecture/system-reference.md) - Technical deep dive
- [Documentation Index](DOCUMENTATION_INDEX.md) - Complete navigation

**Planning:**
- [Roadmap](ROADMAP.md) - What I'm becoming
- [Migration Guide](MIGRATION_GUIDE.md) - Repository split history

## Helper Scripts (Token Optimizers)

I have 12+ bash scripts that reduce Claude Code token usage by 60-70%:

**On me (Raspberry Pi `~/`):**
- `nexus-quick.sh` - Ultra-fast health check ⚡ (most used)
- `nexus-health.sh` - Comprehensive system status
- `nexus-n8n-status.sh` - n8n workflow debugging
- `nexus-backup-status.sh` - Backup status
- `nexus-logs.sh <service>` - Smart log viewer

**On WSL2 (local):**
- `nexus-git-push "message"` - Automated git workflow
- `nexus-deploy <file> <remote> <service>` - Deploy and restart

```bash
# Quick session start
~/ssh-nexus '~/nexus-quick.sh'

# After making changes
nexus-deploy scripts/file.py /srv/projects/factsmind/scripts/file.py
nexus-git-push "feat: Update monitoring"
```

See [scripts/README.md](scripts/README.md) for complete documentation.

## Critical Notes

### For Claude Code Sessions

**Image Transfer (CRITICAL):**
❌ **NEVER** use `cat` over SSH for binary files (corrupts images):
```bash
# WRONG - causes corruption
~/ssh-nexus 'cat /srv/outputs/slide.png > /tmp/slide.png'
```

✅ **ALWAYS** use `scp` for images:
```bash
# CORRECT
scp didac@100.122.207.23:/srv/outputs/slide.png /tmp/slide.png
```

**n8n Workflows:**
- ❌ Don't read workflow JSON files (triggers API errors)
- ❌ Don't programmatically deploy workflows
- ✅ Only manage Python scripts, fonts, outputs
- ✅ User handles all workflows via web UI

**Working Directory:**
When working on me (Nexus infrastructure), stay in this repo. FactsMind application work happens in `/home/dvayr/Projects_linux/factsmind/`.

See [docs/ai-context/claude.md](docs/ai-context/claude.md) for complete context.

## My Philosophy

I aim for **stability first**. I look for better ways to:
- Improve system reliability
- Add more tools and capabilities
- Analyze my own data
- Control my vitals
- Self-heal when issues arise

I'm built to be a **0-to-100 content creation machine** - provide the branding and project requirements, and I'll provide the infrastructure to make it happen.

## Development Workflow

```bash
# Clone my repository
git clone <repo-url> nexus
cd nexus

# Work on infrastructure (Docker, monitoring, scripts)
# Deploy changes to me:
~/ssh-nexus 'cd /srv/docker && sudo docker compose up -d'

# Commit using conventional format
git commit -m "feat: Add new monitoring capability"
```

**Git Conventions:**
- Use conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`
- Include `🤖 Generated with Claude Code`
- Add `Co-Authored-By: Claude <noreply@anthropic.com>`

## Future Vision

**Phase 1: Stability** (In Progress)
- Self-awareness and health monitoring
- Automated self-healing
- Resource optimization for 4GB Pi

**Phase 2: Multi-Project Support**
- Application templates and onboarding
- Project isolation and management
- Shared infrastructure optimization

**Phase 3: Migration Ready**
- When I outgrow the Pi, migrate to a more powerful server
- All access/management stays via Claude Code
- Designed for portability from day one

See [ROADMAP.md](ROADMAP.md) for detailed development plan.

## License

Private project - All rights reserved

## Maintainer

Built and maintained by @selto
Powered by Claude Code
Running 24/7 on Raspberry Pi 4
