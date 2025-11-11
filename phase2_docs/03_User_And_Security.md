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
