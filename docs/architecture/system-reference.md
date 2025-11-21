---
version: 1.0
generated: 2025-11-10T19:16:36Z
maintainer: selto
---

# Nexus Documentation v1.0 (Merged)

## Phase 0: Project Overview

---
version: 1.0
last_updated: 2025-11-10T19:06:17Z
maintainer: selto
---

# 00_Nexus_Project_Overview

## Objective
Provide a concise conceptual overview of the Nexus system. Explain purpose, architecture, workflows, and design principles so any operator understands what the system is and why it exists.

## Applies to
Raspberry Pi 4 (nexus) with NASPi V2.0 case, internal SATA system SSD, external USB3 backup drive, Docker Compose stack (n8n, PostgreSQL, code-server, Netdata, Watchtower), Tailscale remote access.

---
## What is Nexus?
Nexus is a self-contained automation workstation built to generate, render and publish short-form content (carousels, shorts) using AI and scripted automation. It is intended to be resilient, observable and recoverable. Nexus runs on a Raspberry Pi 4 as a low-power production node and is designed to be migrated to more powerful hardware when needed.

## Core idea
Three closed loops:
- **Creation loop**: Prompts (Claude/Groq/Gemini) -> generate facts/text -> select images -> render final assets.
- **Automation loop**: n8n orchestrates the generation, reviews, approvals and publishes to channels (IG/X/TikTok/YouTube).
- **Recovery loop**: rsync + rclone + dd images ensure backups and full system rebuilds are possible.

## Architecture (high level)
| Layer | Component | Role |
|---|---:|---|
| Hardware | Raspberry Pi 4 + NASPi V2.0 | Host node, internal system SSD |
| Storage | Internal SATA SSD, External USB3 backup | System + local backups |
| Network | LAN + Tailscale | Local access + secure remote access |
| Runtime | Docker Compose | Containerized services and isolation |
| Services | n8n, Postgres, code-server, Netdata, Watchtower | Orchestration, persistence, IDE, monitoring, updates |
| Backup | rsync, rclone, dd | Local snapshots + offsite sync |
| Security | SSH keys, read-only containers, secrets | Access control and containment |

## Workflow lifecycle (simple)
1. **Generate**: n8n scheduled trigger calls AI to create text/facts.  
2. **Fetch**: Pexels API (or local assets) provides candidate images.  
3. **Compose**: Python/FFmpeg scripts render 5-slide carousels and short videos.  
4. **Review**: Telegram manual review step. Human approves candidate.  
5. **Publish**: n8n uploads to platform APIs or queues for manual publish.  
6. **Track**: Post metadata stored in Postgres and aggregated for performance tuning.

## Design principles
- **Autonomy**: minimize manual work. Start automatic, remain human-in-the-loop until stable.
- **Observability**: metrics and logs for every stage. Netdata + Postgres events table.
- **Recoverability**: full-image restore and per-artifact verification via checksums.
- **Modularity**: replaceable services and clear APIs between components.
- **Security**: least-privilege tokens, SSH-only access, read-only containers where feasible.

## Next steps
After Phase 1 docs you will get a full system setup guide, application deployment examples and operational runbooks. This file is the anchor: link to it from README.md so new contributors read it first.


## Phase 1: System and Architecture

---
version: 1.0
last_updated: 2025-11-10T19:06:17Z
maintainer: selto
---

# 01_System_And_Architecture

## Objective
Turn a blank Raspberry Pi 4 + NASPi V2.0 kit into a stable 'nexus' host. Provide boot, power, storage and tuning commands for production use.

## Applies to
Raspberry Pi 4 (8GB recommended), NASPi V2.0 case, 2.5" SATA internal SSD (system), USB3 external SSD for backup, 5V/5A USB-C PSU, Tailscale for remote access.

---
## High-level hardware map
- Pi hostname: `nexus`
- Internal system SSD: `/dev/sda` (installed in NASPi V2.0 bay)
- External USB3 backup: `/dev/sdb` (mounted as `/mnt/backup`)
- Power input: USB-C 5V/5A to Pi; fan powered from Pi GPIO or case header
- Network: wired preferred for stability; fallback: Wi-Fi + Tailscale

---
## 1. Flashing Ubuntu Server 24.04 and first boot
1. Download Ubuntu Server 24.04 ARM64 image.
2. Write to SSD using Raspberry Pi Imager or `dd`.
3. Insert SSD into NASPi bay and boot Pi from USB3 port.

Quick commands (from your workstation):
```bash
# example with Raspberry Pi Imager omitted — dd alternative:
xzcat ubuntu-24.04-server-arm64.img.xz | sudo dd of=/dev/sdX bs=4M status=progress && sync
```
If Pi doesn't boot from SSD, update EEPROM once:
```bash
sudo apt update && sudo apt install -y rpi-eeprom
sudo rpi-eeprom-update -a
```
Reboot and verify `lsblk` and `hostnamectl`.

---
## 2. Create user and basic hardening
```bash
# create main operator
sudo adduser didac
sudo usermod -aG sudo,docker didac
sudo hostnamectl set-hostname nexus
# disable root password login
sudo passwd -l root
```
Configure SSH keys (see Security doc).

---
## 3. Partition and mount backup disk (USB3 external)
Identify disk:
```bash
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINT
```
Format and mount (example using /dev/sdb1):
```bash
sudo mkfs.ext4 -L backup_disk /dev/sdb1
_UUID=$(sudo blkid -s UUID -o value /dev/sdb1)
sudo mkdir -p /mnt/backup
echo "UUID=${_UUID} /mnt/backup ext4 defaults,noatime,nofail 0 2" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown -R didac:didac /mnt/backup
```
Use `noatime` to reduce writes.

---
## 4. Power and cooling checklist
- Use a high-quality **5V/5A USB-C** supply. Prefer branded adapter and a thick short USB-C cable rated ≥5A.
- Confirm no undervoltage: `vcgencmd get_throttled` (0x0 is clean).
- NASPi fan: wire to the case header or Pi GPIO 5V/PWM. Verify fan spins at boot.
- Monitor temperatures: `vcgencmd measure_temp` and `smartctl -a -d sat /dev/sda` (if supported).

---
## 5. System tuning (reduce SD/USB wear)
Set journal to volatile to limit disk writes:
```bash
sudo bash -c 'cat > /etc/systemd/journald.conf <<EOF
[Journal]
Storage=volatile
SystemMaxUse=50M
RuntimeMaxUse=50M
EOF'
sudo systemctl restart systemd-journald
```
Enable TRIM and zram:
```bash
sudo systemctl enable fstrim.timer
sudo apt install -y zram-tools
sudo systemctl enable zramswap.service || true
```

---
## 6. Useful hardware tests
```bash
# check read speed
sudo apt install -y hdparm fio
sudo hdparm -tT /dev/sda
# quick write test (destructive) - be careful
fio --name=seqwrite --rw=write --bs=1M --size=1G --numjobs=1 --runtime=60 --group_reporting --filename=/dev/sda
```
Record results in the Hardware doc for reference.

---
## 7. Folder layout (persistent)
```text
/srv/projects/
├── nexus/                          # Main repository
├── factsmind/
│   ├── scripts/                    # Python processing scripts
│   └── assets/                     # Permanent assets (Samba accessible)
│       ├── audio/                  # Permanent audio files
│       ├── fonts/                  # Typography (Montserrat, Poppins)
│       ├── images/                 # Permanent images
│       └── logos/                  # Brand assets
/srv/outputs/                       # Generated content (daily rotation)
/srv/bin/                          # Static binaries (ffmpeg, ffprobe)
/mnt/backup/                       # External backup drive
```
Set ownership to `didac`:
```bash
sudo mkdir -p /srv/projects/{nexus,factsmind/{scripts,assets/{audio,fonts,images,logos}}} /srv/outputs /srv/bin
sudo chown -R didac:didac /srv
```

### Asset Management
Permanent assets are stored in `/srv/projects/factsmind/assets/` and accessible via:
- **Samba share:** `\\100.122.207.23\factsmind-assets`
- **Container mount:** `/data/assets/` (inside n8n)
- **Usage:** Logos, fonts, intro music, brand guidelines

See [Assets Management Guide](../operations/assets-management.md) for details.

---
## 8. Boot and service order
Recommendation: run Docker Compose under a systemd unit so the stack starts on boot after network online. Example unit is in Applications guide.

---
## 9. Quick verification checklist
- `ssh didac@nexus` works.
- `lsblk` shows `/dev/sda` and `/dev/sdb`.
- `df -h` shows `/mnt/backup` mounted.
- Docker installed and `docker ps` returns empty list initially.


## Phase 1: Applications Setup

---
version: 1.0
last_updated: 2025-11-10T19:06:17Z
maintainer: selto
---

# 02_Applications_Setup_Guide

## Objective
Install and configure the core Docker services: PostgreSQL, n8n, code-server, Netdata and Watchtower. Provide Docker Compose example, volumes, and run/start/stop commands.

## Applies to
nexus (Pi4 + NASPi V2.0 + USB backup) using Docker and docker-compose plugin on Ubuntu Server 24.04.

---
## 1. Install Docker and docker-compose plugin
```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker didac
sudo apt install -y docker-compose-plugin
# logout/login or new shell for group effect
```
Verify:
```bash
docker version
sudo docker run --rm hello-world
```

---
## 2. Example docker-compose (production-ready fragment)
Save under /srv/docker/docker-compose.yml

```yaml
version: "3.8"
services:
  postgres:
    image: postgres:15
    restart: unless-stopped
    environment:
      POSTGRES_USER: faceless
      POSTGRES_PASSWORD: REPLACE_STRONG_PASSWORD
      POSTGRES_DB: n8n
    volumes:
      - /srv/db/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U faceless"]
      interval: 30s
      timeout: 10s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: faceless
      DB_POSTGRESDB_PASSWORD: REPLACE_STRONG_PASSWORD
      GENERIC_TIMEZONE: Europe/Madrid
      N8N_WORKFLOW_EXECUTIONS_MODE: "queue"
      N8N_MAX_WORKERS: "1"
    ports:
      - "5678:5678"
    volumes:
      - /srv/projects/factsmind/scripts:/data/scripts
      - /srv/projects/factsmind/assets:/data/assets
      - /srv/outputs:/data/outputs
      - /srv/n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy

  code-server:
    image: codercom/code-server:latest
    restart: unless-stopped
    environment:
      PASSWORD: REPLACE_CODE_PASSWORD
    ports:
      - "8080:8080"
    volumes:
      - /srv/projects:/home/coder/project

  netdata:
    image: netdata/netdata
    restart: unless-stopped
    ports:
      - "19999:19999"
    cap_add:
      - SYS_PTRACE
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro

  watchtower:
    image: containrrr/watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 3600
```

Notes:
- Replace REPLACE_STRONG_PASSWORD and REPLACE_CODE_PASSWORD with secure values or use Docker secrets.
- Volumes are host paths mapped to persist data on the SSD.

---
## 3. Start the stack
```bash
sudo mkdir -p /srv/db/postgres /srv/n8n_data /srv/projects /srv/outputs
sudo chown -R didac:didac /srv
cd /srv/docker
sudo docker compose up -d
# check
sudo docker ps
sudo docker logs n8n --tail 50
```

---
## 4. systemd unit (optional) to start compose on boot
Create /etc/systemd/system/nexus-stack.service with:
```ini
[Unit]
Description=Nexus Docker Compose stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/srv/docker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl daemon-reload
sudo systemctl enable nexus-stack.service --now
```

---
## 5. n8n notes
- Use the UI to configure credentials (Pexels, Telegram, Claude via proxy or API).
- For heavy tasks, prefer Execute Command nodes to call scripts rather than running heavy jobs inside n8n process.

---
## 6. Postgres backups
Daily dump example (cron or systemd timer):
```bash
#!/bin/bash
OUT=/mnt/backup/db/postgres_n8n_$(date +%F).sql.gz
sudo docker exec -t postgres pg_dump -U faceless n8n | gzip > "$OUT"
```

---
## 7. code-server
- Access via http://nexus:8080 or Tailscale IP. Use strong password and consider restricting by firewall to Tailscale only.

---
## 8. Netdata alert to Telegram (example)
Netdata can call a webhook; simplest route is to configure a small script that posts to Telegram bot API. Configure health_alarm_notify.conf to call your script or integrate with Netdata cloud.


## Phase 2: User and Security

---
version: 1.0
last_updated: 2025-11-10T19:09:10Z
maintainer: selto
---

# 03_User_And_Security

## Objective
Harden access, manage secrets, and define secure run policies for Nexus. Provide reproducible commands and examples for SSH, Docker hardening, secrets management, and minimal attack surface.

## Applies to
nexus (Pi4 + NASPi V2.0). Focus on SSH key access, Docker containers, credential storage, and incident basics.

---
## 1. SSH and user management
### Create operator account and SSH keys
```bash
# on your PC
ssh-keygen -t ed25519 -C "selto@nexus" -f ~/.ssh/id_ed25519_nexus
# copy public key to nexus
ssh-copy-id -i ~/.ssh/id_ed25519_nexus.pub didac@nexus
```
Disable password authentication on the Pi (edit /etc/ssh/sshd_config):
```
PasswordAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication no
UsePAM no
```
Reload SSH:
```bash
sudo systemctl reload sshd
```
### Lockdown recommendations
- Only allow specific users in `/etc/ssh/sshd_config` using `AllowUsers didac`.
- Use `Fail2ban` if exposing SSH to wider networks (not needed if using Tailscale only).

---
## 2. Docker & container security
### Daemon hardening (`/etc/docker/daemon.json`)
```json
{
  "icc": false,
  "live-restore": true,
  "no-new-privileges": true,
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```
Reload docker after changes:
```bash
sudo systemctl restart docker
```
### Read-only containers example (n8n partial)
```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    read_only: true
    tmpfs:
      - /tmp
    volumes:
      - /srv/n8n_data:/home/node/.n8n
```
Notes:
- Grant write access only to specific volumes. Use `tmpfs` for ephemeral needs.
- Combine with `security_opt: - no-new-privileges:true`.

---
## 3. Secrets and API keys
Options (ranked):
1. **n8n credential store** for workflow-level secrets.
2. **Docker secrets** for production secrets (safest on single-node Docker Swarm).
3. **Environment variables** in `.env` (avoid committing to Git).
4. External secret managers (Vault/Doppler) for long-term scaling.

#### Docker secret creation (example)
```bash
echo "supersecretvalue" | sudo docker secret create postgres_password -
# Use in compose as 'secrets' and reference inside service
```
#### .env example (store in /srv/docker/.env, ensure permissions 600)
```
POSTGRES_PASSWORD=verystrongpassword
CODE_PASSWORD=verystrongpassword2
N8N_GENERIC_TIMEZONE=Europe/Madrid
```

---
## 4. SSH agent forwarding & code-server access
- Do not expose code-server directly to the internet. Bind only to Tailscale or local LAN.
- Use SSH tunnels via Tailscale for secure code-server access.
- Disable password auth for code-server and use strong password or reverse-proxy with basic auth.

---
## 5. API token rotation and policy
- Rotate tokens every 3 months for production. Shorter if tokens are widely used.
- Keep a single token per service and label tokens with purpose (`n8n-pexels-2025-11`).
- Revoke unused tokens immediately.

---
## 6. Incident basics (quick)
- If compromise suspected: pull network cable, `tailscale down`, snapshot disk (`dd`), collect logs (`journalctl -b -n 500 > /tmp/incident.log`), rotate keys.
- Store incident history in Postgres `events` table for auditability.

---
## 7. Audit and monitoring integration
- Configure Netdata to send critical alerts to Telegram (see Ops doc).
- Periodically run `git status` on `/srv/projects` and report unexpected modifications.

---
## 8. Useful hardening commands (summary)
```bash
# Update packages
sudo apt update && sudo apt upgrade -y
# Remove unnecessary services
sudo systemctl disable --now bluetooth.service
# Ensure unattended-upgrades configured (careful with auto-reboots)
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```


## Phase 2: Operations and Maintenance

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


## Phase 3: Developer Reference

---
version: 1.0
last_updated: 2025-11-10T19:12:33Z
maintainer: selto
---

# 05_Developer_Reference

## Objective
Reference for developers working on Nexus. Folder layout, naming conventions, JSON schemas, helper scripts, test data and debugging tips.

## Applies to
Local development and deployment workflows for the Nexus project running on Raspberry Pi 4 (nexus).

---
## 1. Repo layout
Recommended repository structure (root):
```
/repo-root
├- README.md
├- CHANGELOG.md
├- docs/
├- scripts/
│  ├- backup_sync.sh
│  ├- pg_backup.sh
│  └- dd_full_image.sh
├- infra/
│  ├- docker-compose.yml
│  └- nexus-stack.service
├- images/
│  └- branding.png
└- tests/
   ├- test_render.py
   └- fixtures/
```
Use `snake_case` for file names and `kebab-case` for branch names.

---
## 2. Pre-commit hooks (basic)
Install and configure `pre-commit` for formatting and linting. Sample `.pre-commit-config.yaml` entries:
```yaml
repos:
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v5.0.0
  hooks:
    - id: end-of-file-fixer
    - id: trailing-whitespace
- repo: https://github.com/psf/black
  rev: 24.1.0
  hooks:
    - id: black
```
Run `pip install pre-commit` and `pre-commit install` in repo root.

---
## 7. Developer workflow notes
- Use feature branches and PRs. Keep main deployable.
- Tag releases using semantic versioning and update CHANGELOG.md.
- Keep sensitive data out of repo. Use secrets in GitHub for CI and Tailscale auth keys.



## Phase 3: CI, Testing and Remote

---
version: 1.0
last_updated: 2025-11-10T19:12:33Z
maintainer: selto
---

# 06_CI_Testing_Remote

## Objective
Describe CI, testing and remote access via Tailscale. Provide automation for running tests and deploying to the nexus device when CI passes.

## Applies to
Repo with Docker Compose infra and Nexus Pi accessible via Tailscale for deploys.

---
## 1. Tailscale automation (auth key method)
On your GitHub Actions or CI runner you can use a one-time or reusable auth key to connect the device for deployments. Generate a machine key via Tailscale admin panel.

Example on Nexus (to use auth key once):
```bash
# install tailscale (if not installed)
curl -fsSL https://tailscale.com/install.sh | sh
# bring up with authkey (replace TS_AUTHKEY)
sudo tailscale up --authkey TS_AUTHKEY --hostname nexus --accept-routes
```

To use in CI for deploys, store TS_AUTHKEY as a GitHub secret and use an SSH step or remote-rsync action to copy files to the Pi via its Tailscale IP.

---
## 2. GitHub Actions deploy example (deploy-prod.yml)
This action builds artifacts and deploys via rsync over SSH to the nexus Tailscale IP when pushed to main.

```yaml
name: Deploy to Nexus
on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build test
        run: echo "Run tests here"
      - name: Copy to Nexus via rsync (over SSH)
        uses: burnett01/rsync-deployments@v4
        with:
          switches: -avz --delete
          path: ./
          remote_path: /srv/projects/nexus  # Or /srv/projects/factsmind for application repo
          remote_host: ${{ secrets.NEXUS_TAILSCALE_IP }}
          remote_user: didac
          remote_key: ${{ secrets.NEXUS_SSH_KEY }}
```

Notes:
- Store `NEXUS_SSH_KEY` as private SSH key secret. Use Tailscale IP for `NEXUS_TAILSCALE_IP`.
- Alternatively use `scp` or actions that support SSH with private key.

---
## 3. Local runner & test matrix
- Use a small local runner (e.g., GitHub self-hosted on a small VM or your PC) for heavy image builds to avoid hitting GitHub minutes limits.
- Use `pytest` for unit tests, and run smoke tests on sample manifests in `tests/`.

---
## 4. Rollback strategy
- Keep previous docker-compose versions in `/srv/docker/releases/` with timestamp.
- Deploy by copying new compose file and running `docker compose up -d --no-deps --build service1 service2`.
- On failure, revert to previous compose and restart.

---
## 5. Security notes for CI
- Never print secrets in CI logs. Use masked secrets.
- Limit deploy key scope to a single host user and home dir only.
- Rotate Tailscale auth keys and SSH deploy keys periodically.



## Phase 4: Security and Compliance

---
version: 1.0
last_updated: 2025-11-10T19:13:30Z
maintainer: selto
---

# 07_Security_And_Compliance

## Objective
Define security incident handling, data policies, retention, and compliance expectations for Nexus. Provide clear, minimal procedures for incidents and periodic compliance checks.

## Applies to
All Nexus services, backups, logs and remote access mechanisms (Tailscale, SSH).

---
## 1. Data classification & retention
- **Ephemeral**: temp files, caches, intermediate assets. Retention: 7 days.
- **Operational**: generated posts, manifests, workflow outputs. Retention: 30 days on local backup, then archived offsite.
- **Critical**: DB dumps, system images. Retention: 6 months (encrypted offsite).

Retention policy examples:
- `/mnt/backup/daily` → rotate keep 30 days
- `/mnt/backup/images` → keep 4 images (weekly)
- `/mnt/backup/db` → keep 90 daily DB dumps, compress older monthly into archive/

---
## 2. Encryption and keys
- Use LUKS for encrypting the backup disk if it will leave secure physical control:
  ```bash
  sudo cryptsetup luksFormat /dev/sdb1
  sudo cryptsetup luksOpen /dev/sdb1 backup_enc
  mkfs.ext4 /dev/mapper/backup_enc
  ```
- Keep LUKS passphrase offline (paper or hardware token).
- Use SSH ED25519 keys for user access. Store private keys in a password manager.
- Use TLS for any exposed web services. Prefer Tailscale-only access for admin UIs.

---
## 3. Incident response playbook (summary)
### A. Suspected compromise (quick)
1. Isolate device: `sudo tailscale down` and unplug LAN if necessary.
2. Snapshot disk: `sudo dd if=/dev/sda of=/tmp/snapshot-$(date +%F).img bs=4M conv=sync,noerror status=progress`
3. Collect logs: `journalctl -b -n 1000 > /tmp/journal.txt` and Docker logs for key services.
4. Rotate secrets: revoke API keys used by n8n, regenerate Docker secrets and update services.
5. Restore from last known good image if integrity cannot be confirmed.
6. Record timeline in Postgres `events` table and create incident ticket.

### B. Data leak suspected
1. Identify scope (which files or DB entries).
2. Disable external connectivity (tailscale down, firewall).
3. Rotate all potentially leaked credentials and notify stakeholders.
4. Preserve affected images and logs for forensic analysis.

---
## 4. Compliance notes
- No PII should be stored unless explicitly approved. If PII is stored, document purpose, retention and encryption method.
- Maintain an access log for admin actions. Store minimal audit entries in Postgres `events` table.
- Periodic review: quarterly policy review and access audit.

---
## 5. Logging & monitoring policy
- Keep system logs minimal. Journald in volatile mode to limit writes.
- Ship critical events to Postgres (events table) for auditability and to Netdata for alerting.
- Netdata alerts to Telegram for critical failures only (avoid alert fatigue).

---
## 6. Legal and export considerations
- Do not store copyrighted media without license. Prefer Pexels/royalty-free sources or ensure proper attribution where required.
- Keep records of any paid API usage and billing to avoid surprises.

---
## 7. Responsible disclosure
- If a vulnerability is found, isolate, patch, and document the vulnerability and mitigation steps. Notify impacted stakeholders.

---
## 8. Checklist (pre-deployment)
- [ ] LUKS or encryption decision made for backup disk
- [ ] SSH keys provisioned, passwords disabled
- [ ] Tailscale configured with ACL and device tagged 'nexus'
- [ ] Netdata alerts configured to Telegram with approved chat IDs
- [ ] Retention rules configured in backup scripts


