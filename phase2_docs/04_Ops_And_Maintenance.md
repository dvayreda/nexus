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
## 2. Backup scripts (real)
### backup_sync.sh (incremental rsync)
Save as `/srv/scripts/backup_sync.sh` and `chmod +x`

```bash
#!/usr/bin/env bash
set -euo pipefail
SRC="/srv/outputs/"
DST="/mnt/backup/daily/$(date +%F)/"
mkdir -p "$DST"
rsync -av --delete --partial --links --perms --times --compress "$SRC" "$DST"
# rotate: keep 30 daily snapshots
find /mnt/backup/daily -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;
# checksum manifest
cd "$DST"
find . -type f -print0 | xargs -0 sha256sum > checksums.sha256
```

### pg_backup.sh (Postgres dump)
Save as `/srv/scripts/pg_backup.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
OUT="/mnt/backup/db/postgres_n8n_$(date +%F).sql.gz"
mkdir -p "$(dirname "$OUT")"
sudo docker exec -t postgres pg_dump -U faceless n8n | gzip > "$OUT"
sha256sum "$OUT" > "${OUT}.sha256"
```

### dd_full_image.sh (weekly full image)
Save as `/srv/scripts/dd_full_image.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
IMG="/mnt/backup/images/nexus-$(date +%F).img"
mkdir -p /mnt/backup/images
sudo dd if=/dev/sda of="$IMG" bs=4M conv=sync,noerror status=progress
sha256sum "$IMG" > "${IMG}.sha256"
# optional compression afterwards (careful with space)
```

---
## 3. systemd timers (replace cron) examples
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

---
## 4. Restore quick steps (high-level)
- To restore postgres DB:
```bash
gunzip -c /mnt/backup/db/postgres_n8n_2025-11-09.sql.gz | sudo docker exec -i postgres psql -U faceless -d n8n
```
- To restore files:
```bash
rsync -av /mnt/backup/daily/2025-11-09/ /srv/outputs/
```
- To restore full image (careful):
```bash
sudo dd if=/mnt/backup/images/nexus-2025-11-09.img of=/dev/sda bs=4M conv=sync,noerror status=progress
```

---
## 5. Verification and checks
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
## 6. Log rotation and cleanup
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
## 7. Monitoring and alerts
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
## 8. Maintenance windows and update process
- Pull images in staging first: `docker compose -f docker-compose.yml pull`
- Stop critical services if needed, update, validate, then restart.
- Keep Watchtower but test updates in staging before promoting to production.

---
## 9. Troubleshooting quick commands
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
