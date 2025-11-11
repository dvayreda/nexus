# Nexus - AI Content Automation Platform

**Status:** 🟡 Pre-deployment (Phase 0)
**Goal:** Automated Instagram content creation and publishing
**Platform:** Raspberry Pi 4 + Docker + n8n + AI

---

## What is Nexus?

Nexus is a self-contained automation workstation designed to generate, render, and publish short-form social media content using AI. Built to run on affordable hardware (Raspberry Pi 4) with emphasis on resilience, observability, and recoverability.

**Target:** 1-3 Instagram carousels per day, expandable to X/TikTok/YouTube
**Tech Stack:** Claude + Groq + Pexels → n8n → PostgreSQL → Instagram API

---

## Current Status

✅ **Complete:**
- Comprehensive architecture documentation
- Docker infrastructure templates
- CI/CD pipeline configuration
- Backup and security strategies

⏳ **In Progress:**
- Phase 0: Hardware setup and Ubuntu installation

🔜 **Upcoming:**
- Phase 1: Docker deployment
- Phase 2: Rendering pipeline (Python + Pillow)
- Phase 3: Instagram integration

---

## Quick Navigation

**First Time Here?**
1. 📖 Read [`CLAUDE.md`](CLAUDE.md) - Overview for AI assistants
2. 🗺️ Review [`IMPLEMENTATION_ROADMAP.md`](IMPLEMENTATION_ROADMAP.md) - Phased deployment plan
3. 🚀 Follow [`QUICK_START.md`](QUICK_START.md) - Step-by-step Pi setup

**Documentation:**
- [`phase1_docs/`](phase1_docs/) - System architecture and initial setup
- [`phase2_docs/`](phase2_docs/) - Security and operations
- [`phase4_docs/`](phase4_docs/) - Compliance and incident response

**When Ready to Deploy:**
```bash
# 1. SSH to the device (assumes Tailscale/SSH configured)
ssh didac@<nexus-tailscale-ip>
# 2. Pull repo to /srv/projects/faceless_prod
git clone <repo> /srv/projects/faceless_prod
# 3. Create folders and permissions
sudo mkdir -p /srv/db/postgres /srv/n8n_data /srv/outputs /mnt/backup
sudo chown -R didac:didac /srv /mnt/backup
# 4. Place .env in /srv/docker/.env with secrets
# 5. Start Docker stack
cd /srv/docker && sudo docker compose up -d
# 6. Enable nexus-stack systemd unit (if configured)
sudo systemctl enable --now nexus-stack.service
# 7. Enable backup timer
sudo systemctl enable --now backup-sync.timer
# 8. Verify services
sudo docker ps
# 9. Check Netdata at http://<nexus-ip>:19999
# 10. Run a test backup
/srv/scripts/backup_sync.sh
```

## Technology Stack

**Hardware:**
- Raspberry Pi 4 (8GB RAM recommended)
- NASPi V2.0 case with SATA bay
- Internal 2.5" SATA SSD (system)
- External USB3 SSD (backups)

**Software:**
- **OS:** Ubuntu Server 24.04 LTS ARM64
- **Runtime:** Docker + Docker Compose
- **Automation:** n8n (workflow orchestration)
- **Database:** PostgreSQL 15
- **Monitoring:** Netdata + Telegram alerts
- **IDE:** code-server (web-based VS Code)

**AI & APIs:**
- **Text Generation:** Claude (quality) + Groq (speed/free)
- **Images:** Pexels (free) → AI-generated (when profitable)
- **Publishing:** Instagram Graph API
- **Notifications:** Telegram Bot API

---

## Project Structure

```
nexus/
├── CLAUDE.md                    # AI assistant guidance
├── IMPLEMENTATION_ROADMAP.md    # Phased deployment plan
├── QUICK_START.md              # First-time setup guide
├── requirements.txt             # Python dependencies
│
├── infra/
│   ├── docker-compose.yml      # Service definitions
│   └── .env.example            # Configuration template
│
├── phase1_docs/                # System setup guides
├── phase2_docs/                # Operations and security
├── phase4_docs/                # Compliance and incidents
│
├── schemas/                    # JSON schemas for validation
├── workflows/                  # Sample n8n workflows
├── tests/                      # Test suite
│
└── (future)
    ├── src/rendering/          # Content generation scripts
    ├── src/api_clients/        # API wrappers
    └── scripts/                # Operational scripts
```

---

## Cost Estimates

**Bootstrap Phase (Months 1-2):**
- Hardware: $150-200 (one-time)
- Claude API: $20-50/month
- Groq: Free
- Pexels: Free
- **Total: ~$20-50/month operating**

**Growth Phase (Revenue-generating):**
- Claude API: $50-100/month
- AI Images: $50-200/month (Midjourney/DALL-E)
- Cloud backup: $5-10/month
- **Total: ~$105-310/month**

**Break-even target:** $150/month revenue

---

## Design Principles

1. **Autonomy** - Minimize manual work through automation
2. **Observability** - Metrics and logs for every stage
3. **Recoverability** - Full backups and disaster recovery
4. **Modularity** - Replaceable components and clear interfaces
5. **Cost-Consciousness** - Free tiers first, scale spending with revenue

---

## Contributing

This is currently a solo project in pre-deployment phase. Once operational:
- Feature branches and PRs
- Semantic versioning
- CHANGELOG.md updates
- Test coverage for new features

---

## License

Private project - not licensed for public use

---

## Maintainer

**selto** - Content creator and automation enthusiast

**Created:** 2025-11-10
**Last Updated:** 2025-11-11
