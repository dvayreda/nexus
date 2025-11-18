---
version: 1.0
last_updated: 2025-11-10T19:09:10Z
maintainer: selto
---

# 04_Ops_And_Maintenance

## Objective
Operational runbook for Nexus. Daily/weekly tasks, backup/restore scripts, systemd timers, health checks, monitoring and maintenance tasks to keep Nexus running reliably.

## Applies to
nexus host environment and Dockerized services. Focus on backups, verification, log rotation and automated maintenance.

---
## 1. Daily quick checklist (2-5 minutes)
- Check Netdata dashboard for CPU, memory, disk IO anomalies.
- `sudo docker ps` to ensure services are running.
- `df -h` to ensure backup disk has free space.
- Check `/var/log/backup_sync.log` for recent rsync errors.

---
## 2. Backup Strategy

### What's Backed Up
✅ **Application data** - /srv/ directory (docker-compose, scripts, templates, outputs)
✅ **n8n workflows & credentials** - Docker volume backup
✅ **Database** - PostgreSQL dumps (SQL format)
✅ **System configs** - Systemd units, SSH config, Docker config
✅ **User data** - Home directory, SSH keys, bash history
✅ **Package list** - dpkg selections for reinstall

### What's NOT Backed Up
❌ **Base OS** - Raspberry Pi OS (needs fresh install)
❌ **Installed packages** - Only list exported (reinstall required)
❌ **Docker engine** - Needs manual reinstall
❌ **Tailscale** - Needs manual reinstall

### Recovery Time
- **Config backup restore**: 1-1.5 hours (works on any hardware)
- **Full image restore**: 2-3 hours (requires exact disk size, disabled to save space)

See `/mnt/backup/RESTORE_INSTRUCTIONS.md` for detailed restore procedures.

---
## 3. Backup scripts (real)
### backup_sync.sh (comprehensive incremental backup)
Save as `/srv/scripts/backup_sync.sh` and `chmod +x`

```bash
#!/usr/bin/env bash
set -euo pipefail

# backup_sync.sh - Comprehensive backup of critical system data and configurations
# Backs up everything needed to rebuild Nexus (except OS base image)

BACKUP_ROOT="/mnt/backup"
TIMESTAMP=$(date +%F_%H-%M-%S)

# Ensure backup directories exist
mkdir -p "$BACKUP_ROOT"/{files,configs,docker-volumes}

echo "=== Starting backup at $(date) ==="

# 1. Application files (/srv/)
echo "[1/7] Backing up /srv/ application files..."
rsync -av --delete /srv/ "$BACKUP_ROOT/files/" 2>&1 | tail -5

# 2. Docker named volumes (n8n workflows, postgres data via volume backup)
echo "[2/7] Backing up Docker volumes (n8n_data)..."
sudo rsync -av --delete \
  /var/lib/docker/volumes/docker_n8n_data/_data/ \
  "$BACKUP_ROOT/docker-volumes/n8n_data/" 2>&1 | tail -5

# Note: postgres_data backed up via pg_backup.sh (SQL dump is better)

# 3. Systemd unit files (timers, services)
echo "[3/7] Backing up systemd units..."
sudo rsync -av --delete \
  /etc/systemd/system/ \
  "$BACKUP_ROOT/configs/systemd/" \
  --exclude="*.wants" \
  --exclude="*.requires" 2>&1 | tail -5

# 4. SSH configuration
echo "[4/7] Backing up SSH config..."
sudo rsync -av /etc/ssh/ "$BACKUP_ROOT/configs/ssh/" 2>&1 | tail -5

# 5. User home directory (excluding cache)
echo "[5/7] Backing up user home directory..."
rsync -av --delete \
  /home/didac/ \
  "$BACKUP_ROOT/configs/home-didac/" \
  --exclude=".cache" \
  --exclude=".local/share/Trash" 2>&1 | tail -5

# 6. Installed packages list
echo "[6/7] Exporting installed packages list..."
dpkg --get-selections > "$BACKUP_ROOT/configs/dpkg-selections.txt"
dpkg -l > "$BACKUP_ROOT/configs/dpkg-full-list.txt"

# 7. Docker daemon configuration
echo "[7/7] Backing up Docker config..."
if [ -d /etc/docker ]; then
  sudo rsync -av /etc/docker/ "$BACKUP_ROOT/configs/docker/" 2>&1 | tail -5
fi

echo "=== Backup completed at $(date) ==="
echo "Backup size: $(du -sh $BACKUP_ROOT | cut -f1)"
```

### pg_backup.sh (Postgres dump)
Save as `/srv/scripts/pg_backup.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

# Ensure the backup directory exists
mkdir -p /mnt/backup/db

# Define the output file path with current date
OUT_FILE="/mnt/backup/db/postgres_n8n_$(date +%F).sql.gz"

# Dump the database, compress it, and write to the output file
sudo docker exec -t nexus-postgres pg_dump -U faceless n8n | gzip > "$OUT_FILE"

# Create checksum
sha256sum "$OUT_FILE" > "${OUT_FILE}.sha256"

# Rotate: keep only last 30 daily database backups
find /mnt/backup/db -name "postgres_n8n_*.sql.gz" -type f -mtime +30 -delete
find /mnt/backup/db -name "postgres_n8n_*.sql.gz.sha256" -type f -mtime +30 -delete

echo "Database backup completed: $OUT_FILE"
```

---
## 4. systemd timers (replace cron) examples
### /etc/systemd/system/backup-sync.service
```ini
[Unit]
Description=Run Nexus backup sync

[Service]
Type=oneshot
ExecStart=/srv/scripts/backup_sync.sh
User=didac
```
### /etc/systemd/system/backup-sync.timer
```ini
[Unit]
Description=Daily backup sync timer

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```
Enable:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now backup-sync.timer
```

**Note:** Full image backup (dd_full_image.sh) has been disabled to save disk space (was 436GB). See `/mnt/backup/RESTORE_INSTRUCTIONS.md` for config-based restore procedures.

---
## 5. Restore quick steps (high-level)
- To restore postgres DB:
```bash
gunzip -c /mnt/backup/db/postgres_n8n_2025-11-09.sql.gz | sudo docker exec -i postgres psql -U faceless -d n8n
```
- To restore application files:
```bash
rsync -av /mnt/backup/files/ /srv/
```
- To restore n8n workflows:
```bash
sudo rsync -av /mnt/backup/docker-volumes/n8n_data/ /var/lib/docker/volumes/docker_n8n_data/_data/
```

See `/mnt/backup/RESTORE_INSTRUCTIONS.md` for full system restore from scratch.

---
## 6. Verification and checks
Add periodic verification cron (or systemd timer) to run `/srv/scripts/verify_backups.sh` which checks sha256 manifests and reports via Telegram.

`/srv/scripts/verify_backups.sh` (example)
```bash
#!/usr/bin/env bash
set -euo pipefail
BASE="/mnt/backup/daily/$(date +%F)"
if [ ! -d "$BASE" ]; then
  echo "No backups for today" >&2
  exit 1
fi
cd "$BASE"
sha256sum -c checksums.sha256 || { echo "Checksum failed"; exit 2; }
```

---
## 7. Log rotation and cleanup
Configure `logrotate` for docker logs if using json-file driver (or rely on daemon log-opts). Example `/etc/logrotate.d/nexus`:
```
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  compress
  missingok
  notifempty
  copytruncate
}
```

---
## 8. Monitoring and alerts
- Netdata installed as container. Configure `health_alarm_notify.conf` to call a small script that posts to Telegram via bot token.
- Key alerts: disk < 10%, postgres not running, n8n failure rate > 5%, high I/O waits.
- Example minimal alert script `/srv/scripts/netdata_alert_to_telegram.sh`:
```bash
#!/usr/bin/env bash
CHAT_ID="YOUR_CHAT_ID"
BOT_TOKEN="YOUR_BOT_TOKEN"
MSG="$*"
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d text="${MSG}"
```

---
## 9. Maintenance windows and update process
- Pull images in staging first: `docker compose -f docker-compose.yml pull`
- Stop critical services if needed, update, validate, then restart.
- Keep Watchtower but test updates in staging before promoting to production.

---
## 10. Troubleshooting quick commands
```bash
# Container logs
sudo docker logs n8n --tail 200
# Disk usage
df -h /srv /mnt/backup
# Docker stats
sudo docker stats --no-stream
# Check failed systemd units
sudo systemctl --failed
# Journal logs
sudo journalctl -u nexus-stack.service -n 200
```
