# Nexus

**Self-hosted AI content automation platform running on Raspberry Pi**

Nexus is a complete automation workstation for generating, rendering, and publishing AI-powered social media content. Built to run 24/7 on low-power hardware with enterprise-grade reliability.

## Current Status

✅ **Production Ready** - FactsMind carousel generation with complete visual polish (Nov 2025)
🎯 **Platform:** Instagram (4-slide carousels)
🤖 **AI Stack:** Google Gemini (content + images) + Python/Pillow (pure Python rendering)
🎨 **Design:** Montserrat typography, dark navy + cyan glow, professional effects

## What It Does

1. **Generates** educational content using Google Gemini AI
2. **Creates** custom images with Gemini imagen-3.0 (1024x1024)
3. **Composes** professional 4-slide Instagram carousels using pure Python + Pillow
   - Text shadows for readability
   - Image vignette and fade effects
   - Logo with spherical halo
   - Dynamic text spacing (2-5 line support)
4. **Manages** workflows through n8n automation (web UI)
5. **Ready** for Instagram API integration (manual upload currently)

## Architecture

- **Hardware:** Raspberry Pi 4 (4GB RAM, 2GB swap) with SATA SSDs
- **Services:** n8n, PostgreSQL, Redis, Netdata, code-server (all Docker)
- **Network:** Tailscale for secure remote access (100.122.207.23)
- **Backup:** Automated config backups + PostgreSQL dumps (daily)
- **File Access:** Samba shares for Windows/WSL2 integration

## Quick Links

- **Setup:** [docs/setup/quickstart.md](docs/setup/quickstart.md)
- **FactsMind Project:** [docs/projects/factsmind.md](docs/projects/factsmind.md) ← **Complete build documentation**
- **Architecture:** [docs/architecture/system-reference.md](docs/architecture/system-reference.md)
- **Operations:** [docs/operations/maintenance.md](docs/operations/maintenance.md)
- **AI Context:** [docs/ai-context/claude.md](docs/ai-context/claude.md) ← **For Claude Code sessions**
- **n8n MCP Setup:** [docs/operations/n8n-mcp-setup.md](docs/operations/n8n-mcp-setup.md)

## Tech Stack

**Docker Services:**
- nexus-n8n (automation orchestrator with Python 3.12 + Pillow 11.0)
- nexus-postgres (database for n8n)
- nexus-redis (queue for n8n executions)
- nexus-netdata (system monitoring)
- nexus-code-server (web IDE)
- nexus-watchtower (auto-updates)

**Content Pipeline:**
- Google Gemini API (fact generation, content expansion, AI image generation)
- Python 3.12 + Pillow 11.0 (pure Python carousel composition)
- Montserrat fonts (ExtraBold, Regular, SemiBold)
- FactsMind logo integration

**No Templates!** - Everything generated programmatically in Python

## Key Features

- ✅ Automated content generation with Google Gemini
- ✅ Custom AI image generation (imagen-3.0, no stock photos)
- ✅ Pure Python carousel rendering with professional visual effects:
  - Text shadows (3px offset, 12px blur, 70% opacity)
  - Image vignette (30% strength for professional look)
  - Image fade transition (gradient to text area)
  - Logo halo (80px spherical black gradient)
  - Dynamic subtitle spacing (adapts to 2-5 lines)
- ✅ Smart text wrapping with orphan prevention
- ✅ Official FactsMind style guide implementation
- ✅ Full system backups and recovery
- ✅ Remote access via Tailscale
- ✅ Samba file sharing for Windows/WSL2
- ✅ 24/7 operation on 15W power budget

## Getting Started

### Access Points

**SSH (via Tailscale):**
```bash
# From WSL2, use wrapper script:
~/ssh-nexus 'docker ps'
~/ssh-nexus 'docker logs nexus-n8n --tail 50'
```

**Web Interfaces:**
- n8n: http://100.122.207.23:5678 (workflow editor)
- code-server: http://100.122.207.23:8080 (web IDE)
- Netdata: http://100.122.207.23:19999 (system monitoring)

**Samba Shares (Windows/WSL2):**
- `\\100.122.207.23\nexus-docker` → Docker configs
- `\\100.122.207.23\nexus-projects` → Python scripts, fonts
- `\\100.122.207.23\nexus-outputs` → Generated carousels

See [docs/ai-context/claude.md](docs/ai-context/claude.md) for complete working environment details.

## Projects

### FactsMind (Production)

Educational Instagram carousel generator creating mind-blowing content about science, psychology, technology, history, and space.

**Current Output:**
- 4-slide carousels (1 hook + 3 reveals)
- 1080x1350px (Instagram native resolution)
- Professional AI-generated images with text overlays
- Dark navy background (#020308) + cyan glow accents (#75E8FF)
- Montserrat typography (ExtraBold/Regular/SemiBold)

**Visual Quality:**
- Text shadows on ALL text for readability
- Image vignette for professional photography look
- Smooth fade transition from image to text
- Logo with spherical halo (doesn't compete with images)
- Larger SWIPE indicator (32px cyan glow)

**Workflow:**
- See [docs/projects/factsmind.md](docs/projects/factsmind.md) for complete implementation details
- Manual trigger → Gemini content generation → 4 parallel image generations → Python composition
- Outputs to `/srv/outputs/final/` (accessible via Samba)

## Development

### Helper Scripts (Token Optimizers)

12 bash scripts that reduce Claude Code token usage by 60-70%:

**On the Pi (`~/`):**
- `nexus-quick.sh` - Ultra-fast health check (most used)
- `nexus-health.sh` - Comprehensive system status
- `nexus-n8n-status.sh` - n8n workflow debugging
- `nexus-backup-status.sh` - Backup status
- `nexus-carousel-recent.sh` - Recent carousel outputs
- And more... (see `scripts/README.md`)

**On WSL2 (local):**
- `nexus-git-push "message"` - Automated git workflow
- `nexus-deploy <file> <remote> <service>` - Deploy and restart

```bash
# Quick start of session
~/ssh-nexus '~/nexus-quick.sh'

# After changes
nexus-deploy scripts/composite.py /srv/projects/faceless_prod/scripts/composite.py
nexus-git-push "feat: Update carousel visual effects"
```

### Python Development

```bash
# Clone repository
git clone <repo-url> nexus
cd nexus

# Install local dev dependencies (optional)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Deploy script updates to server
scp scripts/composite.py didac@100.122.207.23:/srv/projects/faceless_prod/scripts/
```

### Git Workflow

- Commits use conventional format: `feat:`, `fix:`, `refactor:`, `docs:`
- Include `🤖 Generated with Claude Code` in commit messages
- `Co-Authored-By: Claude <noreply@anthropic.com>`

## Documentation Structure

```
docs/
├── setup/           # Installation and configuration
├── projects/        # Project-specific documentation (FactsMind build log)
├── operations/      # Maintenance and ops procedures
├── architecture/    # System design and reference
└── ai-context/      # Instructions for AI assistants (Claude Code, Gemini)

scripts/             # Helper bash scripts for token optimization
  └── README.md      # Complete script documentation
```

## Critical Notes for Claude Code

### Image Transfer (400 Error Fix)
❌ **NEVER** use `cat` over SSH for image files (corrupts binary data)
```bash
# WRONG - causes "Could not process image" 400 error
~/ssh-nexus 'cat /srv/outputs/slide.png > /tmp/slide.png'
```

✅ **ALWAYS** use `scp` for images
```bash
# CORRECT - preserves binary data
scp didac@100.122.207.23:/srv/outputs/slide.png /tmp/slide.png
```

### n8n Workflow Management
- ❌ Don't read workflow JSON files (triggers n8n API)
- ❌ Don't programmatically deploy workflows
- ✅ Only manage Python scripts, fonts, outputs
- ✅ Let user handle workflows via n8n web UI

See [docs/ai-context/claude.md](docs/ai-context/claude.md) for complete context.

## Performance Metrics

- **Image Generation:** ~8-12 seconds per slide (Gemini)
- **Composition:** <1 second per slide (Python)
- **Total Workflow:** ~30-40 seconds (4 slides in parallel)
- **Output Size:** ~1.2-1.5MB per slide (PNG)
- **Power Consumption:** ~15W continuous

## Next Steps

### Immediate
- [ ] Instagram API integration for automated posting
- [ ] Caption generation from carousel metadata
- [ ] Hashtag optimization based on performance

### Short-term
- [ ] YouTube Shorts video generation
- [ ] Multi-platform posting (TikTok, LinkedIn)
- [ ] Analytics dashboard
- [ ] Content calendar scheduling

### Long-term
- [ ] Multi-brand support (different style guides)
- [ ] A/B testing framework
- [ ] Performance analytics integration

## License

Private project - All rights reserved

## Maintainer

Built and maintained by @selto
Powered by Claude Code
