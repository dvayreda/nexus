---
version: 1.0
last_updated: 2025-11-10T19:13:30Z
maintainer: selto
---

# Nexus Documentation (v1.0)

This repository contains the Nexus project documentation for the Raspberry Pi 4 'nexus' host running NASPi V2.0, Docker services and backup workflows.

## Quickstart (10 commands)
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

## Files in this package
- 00_Nexus_Project_Overview.md
- 01_System_And_Architecture.md
- 02_Applications_Setup_Guide.md
- 03_User_And_Security.md
- 04_Ops_And_Maintenance.md
- 05_Developer_Reference.md
- 06_CI_Testing_Remote.md
- 07_Security_And_Compliance.md
- CHANGELOG.md

## Where to start
Read `00_Nexus_Project_Overview.md` then `01_System_And_Architecture.md`. Use `README.md` Quickstart for fast deploy.
