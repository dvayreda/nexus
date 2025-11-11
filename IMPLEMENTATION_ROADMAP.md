# Nexus Implementation Roadmap

**Status:** Pre-deployment planning phase
**Goal:** Monetize through content creation (Instagram priority)
**Target:** 1-3 posts per platform daily
**Budget:** Cost-effective approach using Claude + Groq + Pexels

---

## Phase 0: Hardware Setup (Week 1)
**Status:** NEXT → You are here**

### 0.1 Ubuntu Server Installation on Pi 4
- [ ] Download Ubuntu Server 24.04 LTS ARM64
- [ ] Flash to internal SATA SSD using Raspberry Pi Imager
- [ ] Boot Pi and complete initial setup (hostname: nexus, user: didac)
- [ ] Configure SSH access with key authentication
- [ ] Set up Tailscale for remote access
- [ ] Verify no undervoltage issues (`vcgencmd get_throttled`)

### 0.2 Storage Configuration
- [ ] Format and mount external USB3 backup drive to `/mnt/backup`
- [ ] Create persistent directory structure in `/srv`
- [ ] Configure fstab for automatic backup mount
- [ ] Test write permissions

### 0.3 System Hardening
- [ ] Disable password authentication in SSH
- [ ] Configure journald to volatile mode (reduce SSD wear)
- [ ] Enable TRIM and zram
- [ ] Install and configure fail2ban (optional if Tailscale-only)

### 0.4 Initial Testing
- [ ] Verify SSH access from development machine
- [ ] Confirm fan operation and temperature monitoring
- [ ] Test backup disk read/write speeds
- [ ] Document hardware-specific findings

**Claude Code Support:** Use SSH through Claude Code to execute and document each step

---

## Phase 1: Docker Infrastructure (Week 2)
**Status:** NOT STARTED**

### 1.1 Docker Installation
- [ ] Install Docker Engine via convenience script
- [ ] Install docker-compose plugin
- [ ] Add user to docker group
- [ ] Verify with hello-world container

### 1.2 Core Services Deployment
**Priority order:**
1. PostgreSQL (foundation for everything)
2. n8n (workflow engine)
3. Netdata (monitoring)
4. code-server (development)
5. Watchtower (auto-updates)

**Files to create:**
- `/srv/docker/docker-compose.yml` - Main compose file
- `/srv/docker/.env` - Secrets (git-ignored)
- `/srv/docker/.env.example` - Template for secrets

### 1.3 Systemd Integration
- [ ] Create nexus-stack.service unit
- [ ] Enable auto-start on boot
- [ ] Test restart behavior

### 1.4 Initial Monitoring
- [ ] Access Netdata dashboard
- [ ] Configure basic Telegram alerts
- [ ] Set up disk space warnings

---

## Phase 2: Content Pipeline MVP (Week 3-4)
**Status:** NOT STARTED**
**Focus:** Instagram carousel generation only (simplest to start)**

### 2.1 Rendering Infrastructure
**Create:** `src/rendering/carousel.py`
- Use Pillow for image compositing (lightweight, Pi-friendly)
- Fixed template: 1080x1350px (IG portrait)
- Simple text overlay with good contrast
- 5 slides per carousel

**Dependencies:** `Pillow`, `requests`

### 2.2 API Integration
**Create:** `src/api_clients/`
- `pexels.py` - Image search and download
- `groq_client.py` - Fast text generation (free)
- `claude_client.py` - Review/refinement (paid, use sparingly)

**Strategy:**
- Groq generates initial facts/captions (fast, free)
- Claude reviews and improves quality (slower, paid)
- Pexels provides images (free with attribution)

### 2.3 First n8n Workflow
**Goal:** Semi-automated carousel creation

**Workflow steps:**
1. Manual trigger (run when you want content)
2. Execute Command node → calls Groq for text generation
3. Execute Command node → calls Pexels for images
4. Execute Command node → runs rendering script
5. Telegram notification with preview
6. Human approval via Telegram buttons
7. Store metadata in PostgreSQL

**Why manual trigger first:** Validate the pipeline before automating

### 2.4 Cost Tracking
**Create:** PostgreSQL table for costs
```sql
CREATE TABLE api_costs (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  provider VARCHAR(50),
  operation VARCHAR(100),
  tokens_used INT,
  estimated_cost_usd DECIMAL(10,6),
  workflow_id VARCHAR(100)
);
```

Track every API call to monitor burn rate.

---

## Phase 3: Content Publishing (Week 5)
**Status:** NOT STARTED**

### 3.1 Instagram API Integration
- [ ] Create Instagram Business Account
- [ ] Link to Facebook Page
- [ ] Generate long-lived access token
- [ ] Test carousel upload via API

### 3.2 Publishing Workflow
Extend n8n workflow:
- After human approval → upload to Instagram
- Store post URL and metrics in PostgreSQL
- Schedule posts using n8n cron trigger

### 3.3 Content Calendar
Simple approach:
- JSON file with post schedule
- n8n checks calendar daily at 9 AM
- Generates and queues posts for the day

---

## Phase 4: Backup & Recovery (Week 6)
**Status:** NOT STARTED**

### 4.1 Implement Backup Scripts
- [ ] Create `/srv/scripts/backup_sync.sh` (incremental rsync)
- [ ] Create `/srv/scripts/pg_backup.sh` (database dumps)
- [ ] Create `/srv/scripts/dd_full_image.sh` (weekly full image)

### 4.2 Automate Backups
- [ ] Set up systemd timers
- [ ] Test restoration procedures
- [ ] Verify checksums

### 4.3 Offsite Backup
- [ ] Configure rclone to cloud storage (Google Drive/Backblaze B2)
- [ ] Weekly encrypted backup upload
- [ ] Retention policy enforcement

---

## Phase 5: Optimization & Scaling (Week 7+)
**Status:** NOT STARTED**

### 5.1 Performance Tuning
- Monitor render times on Pi 4
- Optimize image processing (reduce resolution if needed)
- Add caching for frequently used assets
- Set Docker resource limits

### 5.2 Multi-Platform Expansion
Once Instagram is working well:
- [ ] Add X/Twitter support
- [ ] Add TikTok (video format)
- [ ] Add YouTube Shorts

### 5.3 Advanced Features (When Revenue Allows)
- [ ] Switch to AI-generated images (Midjourney/DALL-E)
- [ ] A/B testing for captions
- [ ] Automated hashtag optimization
- [ ] Analytics dashboard
- [ ] Content performance tracking

---

## Cost Estimates (Monthly)

**Current Approach (Bootstrap Mode):**
- Claude API: $20-50/month (pay-as-you-go, use sparingly)
- Groq: $0 (free tier sufficient for 90+ posts/month)
- Pexels: $0 (free with attribution)
- Hosting: $0 (own hardware)
- **Total: ~$20-50/month**

**Future Approach (With Revenue):**
- Claude API: $50-100/month (more usage)
- Groq: $0
- AI Image Generation: $50-200/month (Midjourney Pro)
- Cloud backup: $5-10/month
- **Total: ~$105-310/month**

**Break-even target:** ~$150/month revenue covers all costs

---

## Success Metrics

**Week 4 Goals:**
- [ ] Generate first carousel end-to-end
- [ ] Successfully post to Instagram
- [ ] Track cost per post (target: <$0.50)

**Month 2 Goals:**
- [ ] 30+ posts published
- [ ] Average engagement rate documented
- [ ] All backups automated and tested
- [ ] Total costs <$50

**Month 3 Goals:**
- [ ] Expand to 2nd platform
- [ ] First revenue earned (sponsorship/affiliate/etc)
- [ ] Content quality validated by audience

---

## Risk Mitigation

**Technical Risks:**
- **Pi 4 insufficient:** Can migrate to cloud VM (Hetzner ARM ~$5/month)
- **API costs spike:** Implement daily spend limits in code
- **Rendering too slow:** Reduce resolution or batch overnight

**Business Risks:**
- **No engagement:** Pivot content niche based on analytics
- **Platform policy changes:** Diversify across multiple platforms early
- **Burnout:** Automation prevents manual posting fatigue

---

## Current Blockers

1. **Hardware not set up** → Phase 0 priority
2. **No rendering code** → Phase 2.1 (week 3)
3. **No n8n workflows** → Phase 2.3 (week 4)

**Next Session with Claude Code:**
- SSH into Pi after Ubuntu installation
- Run through Phase 0 checklist
- Document any hardware-specific quirks
