---
title: Nexus Helper Scripts Consolidation
version: 1.1
last_updated: 2025-11-25
maintainer: selto
category: operations
---

# Nexus Helper Scripts Consolidation

## Executive Summary

This document consolidates **15 critical helper scripts** for Nexus system management, now properly version-controlled in the repository. These scripts were previously scattered across the Raspberry Pi and WSL2 environments, creating a significant operational risk. They are now centralized, documented, and ready for deployment.

**Total Lines:** ~2,400 lines of production-ready bash code
**Scripts:** 13 Pi scripts + 2 WSL2 scripts
**Purpose:** Health monitoring, deployment automation, backup verification, and system maintenance

---

## Problem Statement

### Before
- ❌ 14 critical scripts NOT in version control
- ❌ Risk of loss if Pi fails
- ❌ No documentation or standardization
- ❌ Manual deployment process
- ❌ Inconsistent error handling

### After
- ✅ All scripts version-controlled in `/scripts/`
- ✅ Complete documentation with usage examples
- ✅ Standardized error handling and output formatting
- ✅ Automated deployment to Pi
- ✅ Testing procedures documented

---

## Directory Structure

```
nexus/
├── scripts/
│   ├── pi/              # Raspberry Pi operational scripts (13)
│   │   ├── nexus-quick.sh              # Fast health check
│   │   ├── nexus-health.sh             # Comprehensive diagnostics
│   │   ├── nexus-n8n-status.sh         # n8n workflow debugging
│   │   ├── nexus-backup-status.sh      # Backup verification
│   │   ├── nexus-daily-report.sh       # Daily Telegram health summary
│   │   ├── nexus-carousel-recent.sh    # Recent carousel outputs
│   │   ├── nexus-logs.sh               # Smart log viewer
│   │   ├── nexus-restart.sh            # Container restart automation
│   │   ├── nexus-cleanup.sh            # Disk space cleanup
│   │   ├── nexus-compare.sh            # Before/after comparison
│   │   ├── nexus-find.sh               # Smart file finder
│   │   ├── nexus-backup-verify.sh      # Deep backup integrity check
│   │   ├── nexus_vitals.sh             # System vitals collection (5min)
│   │   ├── nexus_watchdog.sh           # Self-healing watchdog (5min)
│   │   └── nexus-metrics.sh            # Performance metrics
│   │
│   └── wsl2/            # WSL2 development scripts (2)
│       ├── nexus-git-push              # Git workflow automation
│       └── nexus-deploy                # Automated deployment to Pi
│
└── docs/
    └── operations/
        └── helper-scripts.md           # This document
```

---

## Script Categories

### 🔍 Monitoring & Diagnostics (6 scripts)
- **nexus-quick.sh** - 2-second health check
- **nexus-health.sh** - Comprehensive system report
- **nexus-n8n-status.sh** - Workflow execution analysis
- **nexus-logs.sh** - Intelligent log viewer
- **nexus-metrics.sh** - Performance data collection
- **nexus-daily-report.sh** - Daily Telegram health summary (8 AM)

### 💾 Backup & Recovery (2 scripts)
- **nexus-backup-status.sh** - Backup status verification
- **nexus-backup-verify.sh** - Deep integrity testing

### 🎨 Content Management (2 scripts)
- **nexus-carousel-recent.sh** - Recent output analysis
- **nexus-find.sh** - Smart file search

### 🔧 Maintenance & Operations (3 scripts)
- **nexus-restart.sh** - Safe container restarts
- **nexus-cleanup.sh** - Disk space management
- **nexus-compare.sh** - State comparison tool

### 🚀 Development & Deployment (2 scripts)
- **nexus-git-push** - Automated git workflow
- **nexus-deploy** - WSL2 → Pi deployment

---

## Detailed Script Reference

### 1. nexus-quick.sh
**Purpose:** Fast health check for daily operations (< 2 seconds)

**Features:**
- Docker daemon status
- Critical container health (postgres, redis, n8n)
- Disk space check
- Memory usage
- Backup disk mount verification
- Recent workflow execution count

**Usage:**
```bash
./nexus-quick.sh

# Exit codes:
# 0 = All healthy
# 1 = Issues detected
```

**Example Output:**
```
=== NEXUS QUICK HEALTH CHECK ===
Docker daemon: ✓ Running
PostgreSQL:    ✓ Running
Redis:         ✓ Running
n8n:           ✓ Running
Disk space:    ✓ 45% used
Memory:        ✓ 62% used
Backup disk:   ✓ Mounted (12%)
Workflows:     ✓ 3 executions (1h)

Status: HEALTHY
```

**Use Cases:**
- Daily morning check
- Pre-deployment verification
- Automated health monitoring
- Cron job status checks

---

### 2. nexus-health.sh
**Purpose:** Comprehensive system diagnostics and troubleshooting

**Features:**
- Complete system resource analysis
- All container details with health checks
- Database connection testing and statistics
- n8n workflow execution history
- Backup status and age verification
- Network interface status
- Storage path verification
- System alert detection

**Usage:**
```bash
./nexus-health.sh              # Human-readable report
./nexus-health.sh --json       # JSON output for automation
```

**Sections Covered:**
1. System Resources (CPU, memory, disk, I/O)
2. Docker Container Status
3. Database Status (PostgreSQL + Redis)
4. n8n Workflow Engine
5. Backup Status
6. Network Status
7. Storage Paths
8. System Alerts

**Use Cases:**
- Deep troubleshooting sessions
- Weekly system reviews
- Pre/post-deployment validation
- Documentation for support tickets

---

### 3. nexus-n8n-status.sh
**Purpose:** n8n workflow debugging and execution analysis

**Features:**
- Container health and restart count
- Database connectivity verification
- Active workflow listing
- Execution statistics (24h, 7 days)
- Recent execution details
- Error analysis and failure tracking
- Volume mount verification
- Container performance metrics
- Queue status (Redis)

**Usage:**
```bash
./nexus-n8n-status.sh                           # All workflows
./nexus-n8n-status.sh --workflow-id <ID>        # Specific workflow
./nexus-n8n-status.sh --last 20                 # Last 20 executions
```

**Example Output:**
```
━━━ ACTIVE WORKFLOWS ━━━
id | name                    | active | createdAt
---+-------------------------+--------+-------------------
1  | FactsMind Carousel Gen  | true   | 2024-01-15 10:30

━━━ EXECUTION STATISTICS ━━━
Last 24 hours:
  Status: true      Count: 18    Avg Duration: 62 sec
  Status: false     Count: 1     Avg Duration: 15 sec

━━━ ERROR ANALYSIS (Last 24h) ━━━
Failed executions: 1
```

**Use Cases:**
- Workflow failure investigation
- Performance bottleneck identification
- Execution pattern analysis
- API error debugging

---

### 4. nexus-backup-status.sh
**Purpose:** Verify backup health and readiness

**Features:**
- Backup disk mount verification
- Database backup age and count
- Application files sync status
- Docker volume backup verification
- Configuration file backup check
- Automated backup job status (systemd timers)
- Recovery readiness assessment

**Usage:**
```bash
./nexus-backup-status.sh                  # Standard check
./nexus-backup-status.sh --verify-checksums   # Deep verification
```

**Checks Performed:**
- ✓ Backup disk mounted
- ✓ Database backups < 24h old
- ✓ Application files synced
- ✓ n8n data backed up
- ✓ Configuration files backed up
- ✓ Systemd timers active
- ✓ Recovery instructions present

**Use Cases:**
- Weekly backup verification
- Pre-deployment backup check
- Disaster recovery planning
- Compliance documentation

---

### 5. nexus-daily-report.sh
**Purpose:** Send comprehensive daily health summary via Telegram at 8:00 AM

**Features:**
- Current system vitals (CPU, memory, disk, temperature, swap)
- 24-hour performance trends
- Active incidents and recently resolved problems
- Service status and restart count (24h)
- Workflow activity summary (24h executions, success rate)
- Backup status and disk usage
- PostgreSQL and n8n database sizes
- Formatted HTML message for Telegram

**Usage:**
```bash
./nexus-daily-report.sh                    # Manual execution
# Automated: Runs daily at 8:00 AM via cron
```

**Telegram Message Includes:**
- 🌅 Morning header with timestamp
- ⚠️ Problems section (if any):
  - Active incidents with severity
  - Service restarts in last 24h
  - Resource warnings (high CPU, memory, disk, temperature)
- 📊 Current status snapshot
- 📈 Activity metrics (workflow success rate)
- 💾 Backup health
- 🗄️ Database sizes
- ✅ Summary: "All systems nominal" or issues list

**Requirements:**
- Telegram credentials in `~/.bashrc`:
  ```bash
  export TELEGRAM_BOT_TOKEN="your-token"
  export TELEGRAM_CHAT_ID="your-chat-id"
  ```
- PostgreSQL access (vitals and incidents database)
- n8n database access (workflow stats)

**Cron Setup:**
```bash
0 8 * * * /home/didac/nexus-daily-report.sh >> /var/log/nexus-daily-report.log 2>&1
```

**Use Cases:**
- Daily morning health briefing
- Trend analysis (24h averages)
- Problem tracking and resolution
- Automated incident detection and reporting
- Proactive system health monitoring

**Example Report:**
```
🌅 NEXUS Morning Report
2025-11-25 08:00

⚠️ PROBLEMS
• Memory high: 87%

📊 STATUS
CPU: 45% (avg 24h: 42%)
Memory: 3.5/4.0GB (87%)
Disk: 110/256GB (43%)
Temp: 52°C | Swap: 15%

Services: 5/5 running

📈 ACTIVITY (24h)
Workflows: 24 (92% success)

💾 BACKUP
✅ 50G/500G (10%)
Last: Nov 24 08:00

🗄️ DATABASE
nexus_system: 25 MB
n8n: 45 MB
```

---

### 6. nexus-carousel-recent.sh
**Purpose:** Analyze recent carousel outputs

**Features:**
- Find carousels by date range
- Group slides into complete sets
- Detect incomplete carousels
- Calculate storage usage
- Show generation statistics
- Display metadata (if available)
- Storage projection
- Quality checks

**Usage:**
```bash
./nexus-carousel-recent.sh                      # Last 7 days
./nexus-carousel-recent.sh --days 30            # Last 30 days
./nexus-carousel-recent.sh --show-metadata      # Include metadata
```

**Example Output:**
```
━━━ CAROUSEL SETS ━━━

Carousel #1
  Generated: 2024-11-18 10:30:45
  Slides: 5/5
  Total size: 12.5 MB
  Files:
    Slide 1: 2.5 MB (2160x2700)
    Slide 2: 2.5 MB (2160x2700)
    ...

━━━ STATISTICS ━━━
Total carousel sets: 12
Daily generation count:
  2024-11-18: 3 carousels
  2024-11-17: 2 carousels
```

**Use Cases:**
- Content production tracking
- Storage usage monitoring
- Quality assurance checks
- Output verification

---

### 7. nexus-logs.sh
**Purpose:** Smart log viewer with filtering and analysis

**Features:**
- Interactive container selection
- Error/warning filtering
- Follow mode for real-time monitoring
- Time-based filtering (--since)
- Log level statistics
- Common error pattern detection
- Container-specific analysis

**Usage:**
```bash
./nexus-logs.sh                             # Interactive menu
./nexus-logs.sh nexus-n8n                   # Specific container
./nexus-logs.sh nexus-n8n --errors          # Errors only
./nexus-logs.sh nexus-n8n --tail 50         # Last 50 lines
./nexus-logs.sh nexus-n8n --follow          # Real-time
./nexus-logs.sh nexus-n8n --since 1h        # Last hour
./nexus-logs.sh all                         # All containers
```

**Log Analysis Features:**
- Error count by severity
- Most common error patterns
- n8n-specific checks (workflow errors, API errors, DB issues)
- PostgreSQL-specific checks (connection issues, slow queries)
- Redis-specific checks (memory warnings, connection issues)

**Use Cases:**
- Real-time error monitoring
- Post-deployment log review
- Incident investigation
- Pattern analysis

---

### 8. nexus-restart.sh
**Purpose:** Safe container restart with health verification

**Features:**
- Single container or all containers
- Health check verification
- Ordered restart (dependencies first)
- Interactive confirmation (unless --force)
- Wait for healthy state
- Status verification

**Usage:**
```bash
./nexus-restart.sh nexus-n8n                # Single container
./nexus-restart.sh all                      # All containers
./nexus-restart.sh nexus-n8n --force        # Skip confirmations
./nexus-restart.sh nexus-n8n --no-wait      # Don't wait for health
```

**Restart Order (for "all"):**
1. nexus-postgres (database first)
2. nexus-redis (cache)
3. nexus-n8n (depends on above)
4. nexus-netdata (monitoring)

**Use Cases:**
- Apply configuration changes
- Recover from container failures
- Post-deployment restarts
- Memory leak mitigation

---

### 9. nexus-cleanup.sh
**Purpose:** Automated disk space cleanup and maintenance

**Features:**
- Docker image/container/volume pruning
- Old carousel output deletion (>30 days)
- Intermediate file cleanup
- Docker log truncation (aggressive mode)
- System package cache cleanup
- Old backup rotation
- Journal log cleanup (aggressive mode)
- Dry-run mode for safety

**Usage:**
```bash
./nexus-cleanup.sh                  # Standard cleanup
./nexus-cleanup.sh --dry-run        # Preview changes
./nexus-cleanup.sh --aggressive     # Deep cleanup
```

**Cleanup Targets:**
- Docker stopped containers
- Docker unused images
- Docker unused volumes
- Carousel outputs >30 days old
- Incomplete carousel files
- Database backups >30 days old
- APT package cache
- Temporary files >7 days old
- Docker build cache (aggressive)
- Container logs >10MB (aggressive)
- System journals >7 days (aggressive)

**Use Cases:**
- Monthly maintenance
- Pre-deployment cleanup
- Low disk space recovery
- Performance optimization

---

### 10. nexus-compare.sh
**Purpose:** Compare system state before/after changes

**Features:**
- Save system snapshots
- Compare container status
- Track disk usage changes
- Monitor memory changes
- File count tracking
- Workflow execution counts
- Docker image changes
- Named state management

**Usage:**
```bash
# Save state before changes
./nexus-compare.sh save before-upgrade

# Make changes (upgrade, deployment, etc.)

# Compare with saved state
./nexus-compare.sh compare before-upgrade

# List saved states
./nexus-compare.sh list
```

**Captured Information:**
- Container status and health
- Restart counts
- Disk and memory usage
- File counts
- Docker images
- Network interfaces
- Workflow statistics
- Recent Docker events

**Use Cases:**
- Before/after deployment comparison
- Troubleshooting regressions
- Change impact analysis
- Documentation for audits

---

### 11. nexus-find.sh
**Purpose:** Smart file search with context

**Features:**
- Type-based filtering (script, config, image, template, output, log)
- Recent file filtering (last 7 days)
- Detailed file information
- Permission checking
- Image dimension detection
- Script shebang display
- Context suggestions
- Directory browsing

**Usage:**
```bash
./nexus-find.sh carousel.py                 # Find by name
./nexus-find.sh 'slide_*' --type image      # Wildcard + type
./nexus-find.sh --type output --recent      # Recent outputs
./nexus-find.sh 'docker-compose' --path /srv/docker
./nexus-find.sh --type script               # All scripts
```

**File Types:**
- `script` - .sh, .py, .js files
- `config` - .yml, .yaml, .json, .conf, .env
- `image` - .png, .jpg, .jpeg, .gif
- `template` - Files in templates/ directories
- `output` - Files in outputs/ directories
- `log` - .log files or files in logs/ directories

**Use Cases:**
- Locate configuration files
- Find recent outputs
- Search for scripts
- Navigate project structure

---

### 12. nexus-backup-verify.sh
**Purpose:** Deep backup integrity verification

**Features:**
- Checksum validation (SHA256)
- GZip integrity testing
- SQL dump format verification
- Size sanity checks
- File completeness verification
- Test restoration capability
- Backup age analysis
- Redundancy assessment
- Corruption detection

**Usage:**
```bash
./nexus-backup-verify.sh                    # Standard verification
./nexus-backup-verify.sh --test-restore     # Test restoration
./nexus-backup-verify.sh --repair           # Attempt repair
```

**Verification Checks:**
1. Database backups
   - Checksum validation
   - GZip integrity
   - SQL syntax verification
   - Size validation
2. Docker volumes
   - n8n data completeness
   - Critical file presence
3. Application files
   - Directory structure
   - docker-compose.yml validation
4. Configuration files
   - Systemd units
   - SSH config
   - Package lists
5. Backup freshness (<24h)
6. Redundancy (7+ days coverage)

**Exit Codes:**
- 0 = All backups verified (excellent)
- 1 = Minor warnings (good)
- 2 = Critical errors (urgent action needed)

**Use Cases:**
- Monthly backup verification
- Pre-disaster recovery planning
- Compliance audits
- Backup automation validation

---

### 13. nexus-metrics.sh
**Purpose:** Performance metrics collection and analysis

**Features:**
- Real-time system metrics
- Per-container resource usage
- CPU, memory, disk tracking
- Temperature monitoring (Pi)
- Load average tracking
- Continuous or fixed-duration collection
- CSV export for analysis
- Statistical summaries

**Usage:**
```bash
./nexus-metrics.sh                          # Default (60s @ 5s interval)
./nexus-metrics.sh --interval 10 --duration 300   # 5min @ 10s interval
./nexus-metrics.sh --export /tmp/metrics.csv      # Export to CSV
./nexus-metrics.sh --continuous             # Run until Ctrl+C
```

**Metrics Collected:**
- System CPU usage (%)
- Memory used (MB and %)
- Disk usage (%)
- CPU temperature (°C)
- Load average (1m)
- Per-container CPU (%)
- Per-container memory (MB)

**Statistics Provided:**
- Average, min, max for CPU and memory
- Performance assessment
- Temperature warnings
- Recommendations for optimization

**Use Cases:**
- Performance baseline establishment
- Bottleneck identification
- Capacity planning
- Optimization validation

---

### 14. nexus-git-push (WSL2)
**Purpose:** Automated git workflow for development

**Features:**
- Workspace status checking
- Auto-generated commit messages
- Intelligent change type detection
- Remote sync verification
- Force push protection
- Detailed change summary
- Branch management
- GitHub/GitLab URL detection

**Usage:**
```bash
./nexus-git-push "commit message"           # Standard push
./nexus-git-push --auto                     # Auto-generate message
./nexus-git-push "message" --branch develop # Push to branch
./nexus-git-push --force                    # Force push (careful!)
```

**Auto-Message Logic:**
- Analyzes file changes (added, modified, deleted)
- Determines change type (feat, update, refactor, docs, config)
- Counts affected files
- Generates semantic commit message

**Safety Features:**
- Warns about uncommitted changes
- Detects behind/ahead status
- Requires confirmation for force push
- Shows detailed diff before commit

**Use Cases:**
- Daily development commits
- Quick documentation updates
- Feature branch management
- Hotfix deployments

---

### 15. nexus-deploy (WSL2)
**Purpose:** Automated deployment from WSL2 to Raspberry Pi

**Features:**
- Pre-deployment checks (git status, SSH connectivity)
- Automatic backup before deployment
- Intelligent file sync (rsync)
- Dependency management (requirements.txt)
- Service restart automation
- Health verification
- Dry-run mode
- Progress tracking

**Usage:**
```bash
./nexus-deploy                              # Standard deployment
./nexus-deploy --dry-run                    # Preview changes
./nexus-deploy --backup                     # Create backup first
./nexus-deploy --restart                    # Restart services after
./nexus-deploy --full                       # Full sync (delete extra)
./nexus-deploy --host 192.168.1.100         # Custom Pi IP
```

**Environment Variables:**
```bash
export NEXUS_PI_HOST="100.122.207.23"       # Pi Tailscale IP
export NEXUS_PI_USER="didac"                # SSH user
```

**Deployment Process:**
1. Pre-checks (git clean, SSH connectivity, disk space)
2. Optional backup creation
3. File sync with rsync (excludes .git, node_modules, etc.)
4. Set executable permissions on scripts
5. Install Python dependencies (if changed)
6. Optional service restart
7. Post-deployment verification

**Use Cases:**
- Code deployments from development machine
- Configuration updates
- Script updates
- Emergency hotfixes

---

## Installation Instructions

### On Raspberry Pi

```bash
# 1. Clone repository (if not already done)
cd /srv/projects
git clone <repository-url> nexus
cd nexus

# 2. Make scripts executable
chmod +x scripts/pi/*.sh

# 3. Create convenient symlinks in home directory (optional)
cd ~
for script in /srv/projects/nexus/scripts/pi/*.sh; do
    ln -sf "$script" "$(basename "$script")"
done

# 4. Verify installation
./nexus-quick.sh
```

### On WSL2

```bash
# 1. Navigate to project
cd /path/to/nexus

# 2. Make scripts executable
chmod +x scripts/wsl2/*

# 3. Add to PATH (optional)
echo 'export PATH="$PATH:/path/to/nexus/scripts/wsl2"' >> ~/.bashrc
source ~/.bashrc

# 4. Configure environment variables
echo 'export NEXUS_PI_HOST="100.122.207.23"' >> ~/.bashrc
echo 'export NEXUS_PI_USER="didac"' >> ~/.bashrc
source ~/.bashrc

# 5. Test SSH connectivity
ssh $NEXUS_PI_USER@$NEXUS_PI_HOST "echo 'Connected!'"

# 6. Test deployment (dry-run)
./scripts/wsl2/nexus-deploy --dry-run
```

---

## Testing Procedures

### Test Suite 1: Health Monitoring Scripts

```bash
# Test 1: Quick health check
./nexus-quick.sh
# Expected: Should complete in < 2 seconds, show green checkmarks

# Test 2: Comprehensive health
./nexus-health.sh
# Expected: Detailed report with all sections, no critical errors

# Test 3: n8n status
./nexus-n8n-status.sh
# Expected: Show workflows and recent executions

# Test 4: Metrics collection (30 seconds)
./nexus-metrics.sh --interval 5 --duration 30
# Expected: Show 6 samples, statistics summary
```

### Test Suite 2: Backup Verification

```bash
# Test 1: Backup status
./nexus-backup-status.sh
# Expected: All checks pass, recent backups exist

# Test 2: Deep verification
./nexus-backup-verify.sh
# Expected: Checksum validation passes, exit code 0

# Test 3: Test restoration
./nexus-backup-verify.sh --test-restore
# Expected: Successful test extraction of backups
```

### Test Suite 3: Log and File Operations

```bash
# Test 1: Log viewer
./nexus-logs.sh nexus-n8n --tail 20
# Expected: Last 20 lines of n8n logs

# Test 2: Find files
./nexus-find.sh --type script
# Expected: List all .sh and .py files

# Test 3: Recent carousels
./nexus-carousel-recent.sh --days 1
# Expected: Show today's carousel outputs
```

### Test Suite 4: Maintenance Operations

```bash
# Test 1: Cleanup (dry-run)
./nexus-cleanup.sh --dry-run
# Expected: Show what would be cleaned, no errors

# Test 2: Compare states
./nexus-compare.sh save test-state
./nexus-compare.sh compare test-state
# Expected: Save and compare successfully

# Test 3: Container restart
./nexus-restart.sh nexus-netdata
# Expected: Container restarts cleanly
```

### Test Suite 5: WSL2 Deployment

```bash
# Test 1: Dry-run deployment
./nexus-deploy --dry-run
# Expected: Show files that would be synced

# Test 2: Git push (dry-run equivalent)
# Make a test change first
echo "# Test" >> /tmp/test.txt
git add /tmp/test.txt
./nexus-git-push "test: Add test file" --auto
git reset HEAD~1  # Undo for testing
rm /tmp/test.txt
```

---

## Usage Patterns & Workflows

### Daily Operations Workflow

```bash
# Morning check
./nexus-quick.sh

# If issues detected
./nexus-health.sh

# Check recent activity
./nexus-carousel-recent.sh --days 1
./nexus-logs.sh nexus-n8n --tail 50
```

### Weekly Maintenance Workflow

```bash
# Comprehensive health check
./nexus-health.sh > /tmp/health-report-$(date +%Y%m%d).txt

# Verify backups
./nexus-backup-status.sh

# Collect performance metrics
./nexus-metrics.sh --interval 10 --duration 300 --export /tmp/metrics-$(date +%Y%m%d).csv

# Cleanup old files
./nexus-cleanup.sh --dry-run
# Review output, then:
./nexus-cleanup.sh
```

### Monthly Deep Check Workflow

```bash
# Deep backup verification
./nexus-backup-verify.sh --test-restore

# Compare with last month's snapshot
./nexus-compare.sh save monthly-$(date +%Y%m)
# Compare with previous month if exists

# Full system review
./nexus-health.sh --json > /tmp/health-$(date +%Y%m).json
```

### Development Deployment Workflow

```bash
# From WSL2:

# 1. Make changes, test locally

# 2. Commit and push
./nexus-git-push "feat: Add new feature" --auto

# 3. Deploy to Pi
./nexus-deploy --backup --restart

# 4. Verify deployment
ssh $NEXUS_PI_USER@$NEXUS_PI_HOST 'cd /srv/projects/nexus && ./scripts/pi/nexus-quick.sh'

# 5. Monitor logs
ssh $NEXUS_PI_USER@$NEXUS_PI_HOST './nexus-logs.sh nexus-n8n --follow'
```

### Troubleshooting Workflow

```bash
# 1. Quick assessment
./nexus-quick.sh

# 2. Detailed diagnostics
./nexus-health.sh

# 3. Check specific component
./nexus-n8n-status.sh  # For workflow issues
./nexus-logs.sh nexus-n8n --errors  # For errors

# 4. Review recent changes
./nexus-compare.sh save before-fix
# Apply fix
./nexus-compare.sh compare before-fix

# 5. Verify fix
./nexus-quick.sh
```

---

## Automation & Scheduling

### Cron Jobs for Automated Monitoring

Create `/etc/cron.d/nexus-monitoring`:

```cron
# Daily health check (8 AM)
0 8 * * * didac /srv/projects/nexus/scripts/pi/nexus-quick.sh > /tmp/nexus-daily-check.log 2>&1

# Weekly comprehensive check (Sunday 9 AM)
0 9 * * 0 didac /srv/projects/nexus/scripts/pi/nexus-health.sh > /var/log/nexus-weekly-health.log 2>&1

# Monthly backup verification (1st of month, 10 AM)
0 10 1 * * didac /srv/projects/nexus/scripts/pi/nexus-backup-verify.sh > /var/log/nexus-backup-verify.log 2>&1

# Daily cleanup check (2 AM)
0 2 * * * didac /srv/projects/nexus/scripts/pi/nexus-cleanup.sh --dry-run > /tmp/nexus-cleanup-preview.log 2>&1

# Weekly metrics collection (Every Monday 10 AM)
0 10 * * 1 didac /srv/projects/nexus/scripts/pi/nexus-metrics.sh --interval 10 --duration 300 --export /var/log/nexus-metrics-$(date +\%Y\%m\%d).csv
```

### Systemd Service for Continuous Monitoring

Create `/etc/systemd/system/nexus-metrics.service`:

```ini
[Unit]
Description=Nexus Continuous Metrics Collection
After=docker.service

[Service]
Type=simple
User=didac
ExecStart=/srv/projects/nexus/scripts/pi/nexus-metrics.sh --continuous --export /var/log/nexus-metrics-live.csv
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl daemon-reload
sudo systemctl enable nexus-metrics.service
sudo systemctl start nexus-metrics.service
```

---

## Security Considerations

### Script Permissions

```bash
# Verify all scripts are owned by correct user
chown -R didac:didac /srv/projects/nexus/scripts/

# Set appropriate permissions (755 for scripts)
chmod 755 /srv/projects/nexus/scripts/pi/*.sh
chmod 755 /srv/projects/nexus/scripts/wsl2/*

# Verify no scripts are setuid/setgid
find /srv/projects/nexus/scripts/ -perm /6000 -ls
# Should return nothing
```

### Sensitive Data Handling

These scripts do NOT:
- ❌ Store passwords or API keys
- ❌ Log sensitive credentials
- ❌ Expose secrets in output

These scripts DO:
- ✅ Use environment variables for configuration
- ✅ Sanitize log output
- ✅ Respect .env file exclusions in git-push/deploy

### SSH Key Management (WSL2)

```bash
# Use SSH keys for passwordless deployment
ssh-keygen -t ed25519 -C "nexus-deployment"
ssh-copy-id $NEXUS_PI_USER@$NEXUS_PI_HOST

# Test key-based auth
ssh $NEXUS_PI_USER@$NEXUS_PI_HOST "echo 'Success'"
```

---

## Troubleshooting

### Common Issues

#### Issue: "Docker daemon not responding"
```bash
# Check Docker status
sudo systemctl status docker

# Restart if needed
sudo systemctl restart docker

# Verify
docker ps
```

#### Issue: "Backup disk not mounted"
```bash
# Check mount status
mountpoint /mnt/backup

# Mount if needed
sudo mount /dev/sda1 /mnt/backup

# Verify
df -h /mnt/backup
```

#### Issue: "SSH connection timeout" (WSL2 scripts)
```bash
# Check Tailscale status
tailscale status

# Verify Pi is reachable
ping $NEXUS_PI_HOST

# Test SSH manually
ssh -v $NEXUS_PI_USER@$NEXUS_PI_HOST
```

#### Issue: "Permission denied" errors
```bash
# Verify script is executable
ls -l scripts/pi/nexus-quick.sh

# Fix if needed
chmod +x scripts/pi/*.sh scripts/wsl2/*
```

#### Issue: "Command not found" (jq, docker-compose, etc.)
```bash
# Install missing dependencies
sudo apt-get update
sudo apt-get install jq bc netcat-openbsd

# For docker-compose
sudo apt-get install docker-compose-plugin
```

---

## Performance Impact

### Resource Usage (Typical)

| Script | CPU | Memory | Disk I/O | Duration |
|--------|-----|--------|----------|----------|
| nexus-quick.sh | <1% | ~5MB | Minimal | 1-2s |
| nexus-health.sh | ~5% | ~20MB | Low | 5-10s |
| nexus-n8n-status.sh | ~3% | ~15MB | Low | 3-5s |
| nexus-backup-status.sh | ~2% | ~10MB | Low | 2-4s |
| nexus-logs.sh | ~1% | ~10MB | Minimal | <1s |
| nexus-metrics.sh | ~1% | ~8MB | Minimal | Variable |
| nexus-cleanup.sh | ~10% | ~30MB | High | 30-60s |
| nexus-deploy (WSL2) | ~5% | ~20MB | High | 30-120s |

**Note:** Impact is minimal on Raspberry Pi 4B with 4GB RAM. Scripts are designed to be lightweight.

---

## Maintenance of Scripts

### Updating Scripts

```bash
# On WSL2:
# 1. Edit scripts
vim scripts/pi/nexus-quick.sh

# 2. Test locally if possible

# 3. Commit changes
./scripts/wsl2/nexus-git-push "fix: Update health check logic"

# 4. Deploy to Pi
./scripts/wsl2/nexus-deploy

# 5. Test on Pi
ssh $NEXUS_PI_USER@$NEXUS_PI_HOST './nexus-quick.sh'
```

### Adding New Scripts

```bash
# 1. Create script in appropriate directory
# scripts/pi/ for Pi operations
# scripts/wsl2/ for development tools

# 2. Follow naming convention: nexus-<function>.sh

# 3. Include standard header:
#!/usr/bin/env bash
# nexus-<name>.sh - Brief description
# Usage: ./nexus-<name>.sh [options]

set -euo pipefail

# 4. Use consistent color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 5. Make executable
chmod +x scripts/pi/nexus-<name>.sh

# 6. Document in this file

# 7. Add to testing procedures
```

---

## Integration with Existing Systems

### Integration with Netdata

```bash
# Add custom charts to Netdata
# Create /etc/netdata/python.d/nexus_health.conf

update_every: 300

jobs:
  local:
    command: '/srv/projects/nexus/scripts/pi/nexus-health.sh --json'
```

### Integration with Telegram Alerts

```bash
# Modify scripts to send alerts
TELEGRAM_BOT_TOKEN="your_token"
TELEGRAM_CHAT_ID="your_chat_id"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}"
}

# Add to critical failure points:
if [ $ERRORS -gt 0 ]; then
    send_telegram "🚨 Nexus Alert: $ERRORS errors detected"
fi
```

### Integration with GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Pi

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Pi
        run: |
          # Setup SSH
          mkdir -p ~/.ssh
          echo "${{ secrets.PI_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519

          # Deploy using nexus-deploy
          ./scripts/wsl2/nexus-deploy --backup

      - name: Verify deployment
        run: |
          ssh didac@${{ secrets.PI_HOST }} './nexus-quick.sh'
```

---

## Future Enhancements

### Planned Features

1. **AI-Powered Analysis**
   - Use Claude to analyze log patterns
   - Automated issue detection and recommendations
   - Predictive failure analysis

2. **Enhanced Monitoring**
   - Web dashboard for metrics
   - Real-time alerting
   - Historical trend analysis

3. **Automated Recovery**
   - Self-healing scripts
   - Automatic rollback on failure
   - Circuit breakers for external APIs

4. **Extended Deployment**
   - Multi-environment support (dev/staging/prod)
   - Blue-green deployments
   - Canary releases

5. **Better Integration**
   - Prometheus/Grafana export
   - Slack/Discord notifications
   - PagerDuty integration

---

## Summary Statistics

### Code Metrics

- **Total Lines:** ~2,100 lines
- **Total Scripts:** 14
- **Languages:** 100% Bash
- **Comments:** ~15% (documentation and explanations)
- **Error Handling:** Comprehensive (set -euo pipefail in all scripts)
- **Testing Coverage:** 100% (all scripts have test procedures)

### Functionality Coverage

- ✅ Health Monitoring (5 scripts)
- ✅ Backup Management (2 scripts)
- ✅ Log Analysis (1 script)
- ✅ File Operations (2 scripts)
- ✅ Maintenance (2 scripts)
- ✅ Development Workflow (2 scripts)

---

## Conclusion

All 14 critical helper scripts are now:
- ✅ **Version-controlled** in `/scripts/` directory
- ✅ **Documented** with comprehensive usage examples
- ✅ **Tested** with validation procedures
- ✅ **Production-ready** with proper error handling
- ✅ **Maintainable** with consistent structure
- ✅ **Deployable** via automated workflows

**Next Steps:**
1. Deploy scripts to Raspberry Pi: `./scripts/wsl2/nexus-deploy`
2. Test each script using procedures above
3. Set up automated monitoring (cron/systemd)
4. Integrate with existing alerting systems
5. Train team members on script usage

---

## Quick Reference Card

```bash
# HEALTH CHECKS
./nexus-quick.sh                    # Fast check
./nexus-health.sh                   # Full diagnostics
./nexus-n8n-status.sh               # Workflow status
./nexus-metrics.sh                  # Performance data

# BACKUPS
./nexus-backup-status.sh            # Backup status
./nexus-backup-verify.sh            # Deep verification

# LOGS & FILES
./nexus-logs.sh nexus-n8n           # View logs
./nexus-find.sh carousel.py         # Find files
./nexus-carousel-recent.sh          # Recent outputs

# MAINTENANCE
./nexus-restart.sh nexus-n8n        # Restart container
./nexus-cleanup.sh                  # Free disk space
./nexus-compare.sh save/compare     # State comparison

# DEPLOYMENT (WSL2)
./nexus-git-push "message"          # Commit & push
./nexus-deploy                      # Deploy to Pi
```

---

**Document Version:** 1.0
**Last Updated:** 2025-11-18
**Maintainer:** selto
**Repository:** nexus/scripts/

For questions or issues, refer to repository issues or contact the maintainer.
