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
      - /srv/projects/faceless_prod:/data
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
