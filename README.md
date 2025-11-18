# Nexus

**Self-hosted AI content automation platform running on Raspberry Pi**

Nexus is a complete automation workstation for generating, rendering, and publishing AI-powered social media content. Built to run 24/7 on low-power hardware with enterprise-grade reliability.

## Current Status

✅ **Operational** - FactsMind carousel generation system fully deployed  
🎯 **Platform:** Instagram (1-3 posts/day)  
🤖 **AI Stack:** Groq (facts) + Gemini (content + images) + Python/Pillow (rendering)

## What It Does

1. **Generates** educational content using AI (Groq LLM for facts, Gemini for expansion)
2. **Creates** custom images with Gemini AI image generation
3. **Composes** professional 5-slide Instagram carousels using Python + Pillow
4. **Manages** approval workflows through n8n automation
5. **Publishes** to social platforms (Instagram, X, TikTok, YouTube)

## Architecture

- **Hardware:** Raspberry Pi 4 with NASPi V2.0 case, SATA SSD, USB3 backup
- **Services:** n8n, PostgreSQL, Redis, Netdata, code-server (all Docker)
- **Network:** Tailscale for secure remote access
- **Backup:** rsync + rclone + dd for full system recovery

## Quick Links

- **Setup:** [docs/setup/quickstart.md](docs/setup/quickstart.md)
- **FactsMind Project:** [docs/projects/factsmind.md](docs/projects/factsmind.md)
- **Architecture:** [docs/architecture/system-reference.md](docs/architecture/system-reference.md)
- **Operations:** [docs/operations/maintenance.md](docs/operations/maintenance.md)
- **AI Context:** [docs/ai-context/claude.md](docs/ai-context/claude.md)

## Tech Stack

**Docker Services:**
- n8n (automation orchestrator)
- PostgreSQL (database)
- Redis (queue)
- Netdata (monitoring)
- code-server (web IDE)
- Watchtower (auto-updates)

**Content Pipeline:**
- Groq API (fact generation)
- Google Gemini (content + image AI)
- Python 3.12 + Pillow 11.2 (image composition)
- Figma templates (2160x2700px @ 2x Instagram resolution)

## Key Features

- ✅ Automated content generation with AI
- ✅ Custom image generation (no stock photos needed)
- ✅ Professional carousel templates with smart text overlay
- ✅ Human-in-the-loop approval via Telegram
- ✅ Full system backups and recovery
- ✅ Remote access via Tailscale
- ✅ 24/7 operation on 15W power budget

## Getting Started

1. SSH into the Pi: `ssh didac@100.122.207.23` (via Tailscale)
2. Access n8n: http://100.122.207.23:5678
3. Access code-server: http://100.122.207.23:8080
4. Access monitoring: http://100.122.207.23:19999

See [docs/setup/quickstart.md](docs/setup/quickstart.md) for detailed setup instructions.

## Projects

### FactsMind (Production)
Educational Instagram carousel generator creating mind-blowing science, psychology, technology, history, and space facts.

- **Output:** 5-slide carousels (1080x1350px)
- **Frequency:** 1-3 posts/day
- **Quality:** Professional AI-generated images + branded templates
- **Workflow:** [docs/projects/factsmind.md](docs/projects/factsmind.md)

## Development

```bash
# Clone repository
git clone <repo-url> nexus
cd nexus

# Install local dev dependencies (optional)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run tests
pytest tests/

# Pre-commit hooks
pre-commit install
```

## Documentation Structure

```
docs/
├── setup/           # Installation and configuration
├── projects/        # Project-specific documentation
├── operations/      # Maintenance and ops procedures
├── architecture/    # System design and reference
└── ai-context/      # Instructions for AI assistants (Claude Code, Gemini)
```

## License

Private project - All rights reserved

## Maintainer

Built and maintained by @selto
