# Nexus Helper Scripts

Token-optimizing scripts that reduce command count by 60-70% for common operations.

## Overview

These scripts consolidate repetitive multi-command operations into single commands, making Claude Code workflows more efficient and reducing token usage.

## Pi Scripts (on Raspberry Pi)

Located at `/home/didac/` on the Pi. Call via: `~/ssh-nexus '~/script-name.sh'`

### nexus-quick.sh
**Ultra-fast health check** - Most commonly used

```bash
~/ssh-nexus '~/nexus-quick.sh'
```

**Output:**
- Container count (X/6 running)
- RAM usage
- Disk usage
- CPU temperature
- Failed services count
- Recent n8n errors

**Use when:** Quick status check, starting a session, after making changes

---

### nexus-health.sh
**Comprehensive system status**

```bash
~/ssh-nexus '~/nexus-health.sh'
```

**Output:**
- All containers with status
- Memory, swap, temperature
- System and backup disk usage
- Failed services
- Recent n8n errors

**Use when:** Detailed health check, troubleshooting, health verification

---

### nexus-n8n-status.sh
**n8n workflow debugging**

```bash
~/ssh-nexus '~/nexus-n8n-status.sh'
```

**Output:**
- n8n container status
- Task broker status
- Recent workflow executions
- Errors from last 50 lines

**Use when:** Debugging n8n workflows, checking execution status

---

### nexus-backup-status.sh
**Backup information**

```bash
~/ssh-nexus '~/nexus-backup-status.sh'
```

**Output:**
- Backup disk space
- Scheduled backup timers
- Latest backup files
- Last backup run status

**Use when:** Verifying backups, checking backup health

---

### nexus-carousel-recent.sh
**Recent carousel outputs**

```bash
~/ssh-nexus '~/nexus-carousel-recent.sh'
```

**Output:**
- Latest 5 carousel slides
- Disk usage of outputs
- Last generation timestamp

**Use when:** Checking FactsMind generation status, viewing recent outputs

---

### nexus-logs.sh
**Smart log viewer**

```bash
~/ssh-nexus '~/nexus-logs.sh [service] [lines]'

# Examples:
~/ssh-nexus '~/nexus-logs.sh n8n 50'
~/ssh-nexus '~/nexus-logs.sh postgres'
```

**Arguments:**
- `service` (optional): Container name without "nexus-" prefix (default: n8n)
- `lines` (optional): Number of lines to show (default: 30)

**Output:**
- Recent logs
- Filtered errors/warnings

**Use when:** Debugging container issues, checking for errors

---

### nexus-restart.sh
**Smart container restart with verification**

```bash
~/ssh-nexus '~/nexus-restart.sh <service>'

# Example:
~/ssh-nexus '~/nexus-restart.sh n8n'
```

**Arguments:**
- `service` (required): n8n, postgres, redis, code-server, or netdata

**Output:**
- Restart confirmation
- Container status
- Health check result
- Recent logs

**Use when:** After config changes, fixing hung containers

---

### nexus-cleanup.sh
**Free up disk space**

```bash
~/ssh-nexus '~/nexus-cleanup.sh'
```

**Actions:**
- Removes old raw AI images (>7 days)
- Prunes unused Docker resources
- Cleans systemd journal (keeps 7 days)

**Output:**
- Disk usage before/after
- Items cleaned

**Use when:** Disk space running low, routine maintenance

---

### nexus-compare.sh
**Before/after system comparison**

```bash
# Take snapshot before changes
~/ssh-nexus '~/nexus-compare.sh snapshot'

# Make changes...

# Show what changed
~/ssh-nexus '~/nexus-compare.sh diff'
```

**Output:**
- Diff of containers, memory, disk

**Use when:** Validating changes, debugging unexpected behavior

---

### nexus-find.sh
**Quick file finder**

```bash
~/ssh-nexus '~/nexus-find.sh <keyword>'

# Example:
~/ssh-nexus '~/nexus-find.sh composite'
```

**Output:**
- Matching files in scripts, configs, workflows, outputs

**Use when:** Looking for files, debugging path issues

---

## WSL2 Scripts (on your PC)

Located at `/home/dvayr/` on WSL2. Run directly without SSH wrapper.

### nexus-git-push
**Automated git workflow**

```bash
nexus-git-push "commit message"

# Example:
nexus-git-push "fix: Update carousel template positioning"
```

**Actions:**
1. Checks for changes
2. Shows git status
3. Adds all changes
4. Commits with signature
5. Pushes to origin/main

**Replaces:** 6-8 manual git commands

**Use when:** Committing changes after editing files

---

### nexus-deploy
**Deploy file and restart service**

```bash
nexus-deploy <local_file> <remote_path> <service>

# Example:
nexus-deploy infra/docker-compose.yml /srv/docker/docker-compose.yml n8n
```

**Actions:**
1. Copies file to Pi via SSH
2. Restarts Docker service
3. Shows status
4. Shows recent logs

**Replaces:** 6-8 manual commands

**Use when:** Deploying config changes, updating docker-compose.yml

---

## Token Savings

| Operation | Before | After | Savings |
|-----------|--------|-------|---------|
| Health check | 15 commands | 1 command | 93% |
| Git commit & push | 8 commands | 1 command | 87% |
| Deploy & verify | 8 commands | 1 command | 87% |
| Backup status | 6 commands | 1 command | 83% |
| n8n debugging | 10 commands | 1 command | 90% |
| Log viewing | 5 commands | 1 command | 80% |

**Overall:** ~60-70% reduction in command count for typical workflows

---

## Common Workflows

### Start of Session
```bash
# Quick health check
~/ssh-nexus '~/nexus-quick.sh'
```

### After Making Changes
```bash
# Deploy and verify
nexus-deploy infra/docker-compose.yml /srv/docker/docker-compose.yml n8n

# Check health
~/ssh-nexus '~/nexus-quick.sh'

# Commit if good
nexus-git-push "feat: Your commit message"
```

### Troubleshooting
```bash
# Check system health
~/ssh-nexus '~/nexus-health.sh'

# Check n8n specifically
~/ssh-nexus '~/nexus-n8n-status.sh'

# View detailed logs
~/ssh-nexus '~/nexus-logs.sh n8n 100'
```

### Weekly Maintenance
```bash
# Check backups
~/ssh-nexus '~/nexus-backup-status.sh'

# Clean up space
~/ssh-nexus '~/nexus-cleanup.sh'

# Check carousel outputs
~/ssh-nexus '~/nexus-carousel-recent.sh'
```

---

## Adding More Scripts

To add new helper scripts:

1. Create script in `/tmp/` locally
2. Copy to Pi: `~/ssh-nexus 'cat > ~/script-name.sh' < /tmp/script-name.sh`
3. Make executable: `~/ssh-nexus 'chmod +x ~/script-name.sh'`
4. Test: `~/ssh-nexus '~/script-name.sh'`
5. Document here

---

## Troubleshooting

**Script not found:**
```bash
~/ssh-nexus 'ls -lh ~/nexus-*.sh'
```

**Permission denied:**
```bash
~/ssh-nexus 'chmod +x ~/script-name.sh'
```

**Script errors:**
```bash
# Run with bash -x for debugging
~/ssh-nexus 'bash -x ~/script-name.sh'
```
