# Nexus Application Registry

## Overview

This document tracks all applications running on the Nexus platform, their requirements, and compatibility information.

---

## Active Applications

### FactsMind

**Purpose:** Educational Instagram carousel generator with AI-powered content and image generation.

**Repository:** https://github.com/dvayreda/factsmind

**Version:** v1.0.0

**Status:** ✅ Production (Nov 2025)

**Requirements:**
- Python: 3.12 (provided by nexus-n8n container)
- Pillow: 11.0 (installed in n8n.Dockerfile)
- Fonts: Montserrat ExtraBold, Regular, SemiBold
- n8n: Workflow orchestration

**Volume Mounts:**
```yaml
- /srv/projects/factsmind/scripts:/data/scripts
- /srv/projects/factsmind/assets/fonts:/data/fonts
- /srv/outputs:/data/outputs
```

**Entry Point:**
```bash
python3 /data/scripts/composite.py [args]
```

**Documentation:**
- [Deployment Guide](https://github.com/dvayreda/factsmind/blob/main/docs/deployment.md)
- [Development Guide](https://github.com/dvayreda/factsmind/blob/main/docs/development.md)
- [VERSION.txt](https://github.com/dvayreda/factsmind/blob/main/VERSION.txt)

**Production Paths:**
- Application: `/srv/projects/factsmind/`
- Outputs: `/srv/outputs/final/`
- Workflow: n8n UI (not in git)

**Maintenance:**
```bash
# Update application
ssh didac@100.122.207.23 'cd /srv/projects/factsmind && git pull'
# No restart needed

# Test generation
docker exec nexus-n8n python3 /data/scripts/composite.py --help
```

---

## Platform Requirements

### Current Infrastructure (Nexus v1.0)

**Docker Services:**
- nexus-n8n (Python 3.12 + Pillow 11.0)
- nexus-postgres (pgvector)
- nexus-redis (7-alpine)
- nexus-code-server
- nexus-netdata
- nexus-watchtower

**Provided Capabilities:**
- Python 3.12 runtime
- Pillow 11.0 for image processing
- n8n workflow orchestration
- Docker volume management
- Automated backups

**See:** `infra/docker-compose.yml` and `infra/n8n.Dockerfile`

---

## Compatibility Matrix

| Nexus Version | Python | Pillow | FactsMind Compatible |
|---------------|--------|--------|---------------------|
| 1.0.0         | 3.12   | 11.0   | v1.0.0              |

**Breaking Changes:**
- None yet (initial release)

---

## Adding New Applications

### Prerequisites

1. **Create application repository:**
   - Separate Git repository
   - Include VERSION.txt with requirements
   - Include requirements.txt for Python dependencies

2. **Update Nexus infrastructure:**
   - Add volume mounts to docker-compose.yml
   - Add dependencies to n8n.Dockerfile if needed
   - Update this registry

3. **Deploy to production:**
   - Clone application to `/srv/projects/[app-name]/`
   - Verify volume mounts
   - Test execution

4. **Documentation:**
   - Add entry to this registry
   - Update claude.md if major application
   - Create deployment guide in application repo

### Example: Adding "TechTalks" Application

1. **Create TechTalks repository:**
   ```bash
   gh repo create dvayreda/techtalks --private
   # Add VERSION.txt, requirements.txt, scripts/
   ```

2. **Update Nexus docker-compose.yml:**
   ```yaml
   volumes:
     - /srv/projects/techtalks/scripts:/data/techtalks/scripts
     - /srv/projects/techtalks/assets:/data/techtalks/assets
   ```

3. **Update this registry:**
   - Add TechTalks section above
   - Document requirements and paths

4. **Deploy:**
   ```bash
   ssh didac@100.122.207.23
   cd /srv/projects
   git clone https://github.com/dvayreda/techtalks.git
   ```

---

## Troubleshooting

### Application Not Finding Files

```bash
# Verify volume mounts
docker exec nexus-n8n ls -la /data/scripts/
docker exec nexus-n8n ls -la /data/fonts/

# Should match:
ls -la /srv/projects/factsmind/scripts/
ls -la /srv/projects/factsmind/assets/fonts/
```

### Dependency Conflicts

```bash
# Check installed Python packages
docker exec nexus-n8n python3 -m pip list

# If conflicts arise, consider:
# 1. Separate Docker containers per application
# 2. Python virtual environments
# 3. Version pinning in requirements.txt
```

### Performance Issues

```bash
# Monitor resource usage
~/ssh-nexus '~/nexus-quick.sh'

# Check application logs
docker logs nexus-n8n --tail 100 | grep -i error
```

---

## Future Enhancements

**Planned improvements:**
- Automated compatibility checking (CI/CD)
- Application version tracking in git tags
- Standardized health checks per application
- Performance metrics per application
- Multi-version support (Python 3.12 + 3.13 simultaneously)

**See:** `docs/strategic-analysis/nexus-2.0-vision.md` for long-term roadmap
