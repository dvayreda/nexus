# Nexus Cron Job Setup

**Purpose:** Automate monitoring and self-healing via scheduled tasks

## Overview

Nexus monitoring requires three automated tasks:
1. **Vitals collection** - Every 5 minutes
2. **Service watchdog** - Every 5 minutes
3. **Database cleanup** - Monthly (future)

## Installation

### Step 1: Verify Scripts are Deployed

SSH to Nexus and verify scripts exist:

```bash
~/ssh-nexus 'ls -lh ~/*.sh'
```

You should see:
- `nexus_vitals.sh`
- `nexus_watchdog.sh`
- `nexus_status_simple.sh` (for manual checks)

### Step 2: Create Cron Jobs

Create a cron configuration file:

```bash
~/ssh-nexus 'cat > /tmp/nexus_cron << EOF
# Nexus Monitoring Cron Jobs
# Collect vitals every 5 minutes
*/5 * * * * /home/didac/nexus_vitals.sh >> /var/log/nexus_vitals.log 2>&1

# Run watchdog every 5 minutes (offset by 2 minutes from vitals)
2-59/5 * * * * /home/didac/nexus_watchdog.sh >> /var/log/nexus_watchdog.log 2>&1
EOF
cat /tmp/nexus_cron'
```

### Step 3: Install Cron Jobs

```bash
# Install cron jobs
~/ssh-nexus 'crontab /tmp/nexus_cron'

# Verify installation
~/ssh-nexus 'crontab -l'
```

### Step 4: Create Log Files

```bash
~/ssh-nexus 'sudo touch /var/log/nexus_vitals.log /var/log/nexus_watchdog.log'
~/ssh-nexus 'sudo chown didac:didac /var/log/nexus_*.log'
```

### Step 5: Test Cron Jobs

Wait 5 minutes, then check logs:

```bash
# Check if vitals are being collected
~/ssh-nexus 'tail -n 20 /var/log/nexus_vitals.log'

# Check if watchdog is running
~/ssh-nexus 'tail -n 20 /var/log/nexus_watchdog.log'

# Verify data in database
~/ssh-nexus 'docker exec nexus-postgres psql -U faceless -d nexus_system -c "SELECT COUNT(*) FROM monitoring.vitals"'
```

## Monitoring Schedule

```
Time  | Task           | What Happens
------|----------------|----------------------------------
00:00 | Vitals         | Collect system metrics
00:02 | Watchdog       | Check services, auto-restart if needed
00:05 | Vitals         | Collect system metrics
00:07 | Watchdog       | Check services
...   | ...            | ...
```

Both scripts run every 5 minutes, offset by 2 minutes to avoid overlapping database writes.

## Checking Status

### View Recent Vitals
```bash
~/ssh-nexus '~/nexus_status_simple.sh'
```

### Check Database Directly
```bash
# Count vitals collected
~/ssh-nexus 'docker exec nexus-postgres psql -U faceless -d nexus_system -tAc "SELECT COUNT(*) FROM monitoring.vitals"'

# View latest vitals
~/ssh-nexus 'docker exec nexus-postgres psql -U faceless -d nexus_system -c "SELECT timestamp, cpu_percent, memory_percent, disk_percent FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 5"'
```

### Check Logs
```bash
# Vitals collection log
~/ssh-nexus 'tail -f /var/log/nexus_vitals.log'

# Watchdog log
~/ssh-nexus 'tail -f /var/log/nexus_watchdog.log'
```

## Log Rotation

Create log rotation config to prevent logs from growing too large:

```bash
~/ssh-nexus 'sudo cat > /etc/logrotate.d/nexus << EOF
/var/log/nexus_*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 didac didac
}
EOF'
```

Test log rotation:
```bash
~/ssh-nexus 'sudo logrotate -d /etc/logrotate.d/nexus'
```

## Troubleshooting

### Cron jobs not running?

**Check cron service:**
```bash
~/ssh-nexus 'sudo systemctl status cron'
```

**Check cron logs:**
```bash
~/ssh-nexus 'sudo journalctl -u cron -n 50'
```

**Verify script permissions:**
```bash
~/ssh-nexus 'ls -lh ~/nexus_*.sh'
# Should show -rwxr-xr-x (executable)
```

### No data in database?

**Check if vitals script runs manually:**
```bash
~/ssh-nexus '~/nexus_vitals.sh --verbose'
```

**Check database connection:**
```bash
~/ssh-nexus 'docker ps | grep nexus-postgres'
```

**Check for errors in logs:**
```bash
~/ssh-nexus 'grep ERROR /var/log/nexus_vitals.log'
```

### Watchdog not restarting services?

**Test watchdog in dry-run mode:**
```bash
~/ssh-nexus '~/nexus_watchdog.sh --dry-run'
```

**Check Docker permissions:**
```bash
~/ssh-nexus 'docker ps'
# Should work without sudo
```

## Disabling Monitoring

To temporarily disable:
```bash
# Comment out cron jobs
~/ssh-nexus 'crontab -e'
# Add # at start of nexus lines

# Or remove completely
~/ssh-nexus 'crontab -r'
```

## Related Documentation

- [Monitoring Database](../architecture/monitoring-database.md) - Schema details
- [Telegram Alerts](telegram-alerts.md) - Alert setup
- [ROADMAP.md](../../ROADMAP.md) - Phase 1: Stability Foundation

---

**Last updated:** 2025-01 (Initial cron setup)
