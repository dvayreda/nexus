# Quick Start Guide - Phase 0

**For:** First-time Pi setup and deployment
**Time:** ~2 hours
**Prerequisites:** Pi 4 hardware, USB-C power supply, SATA SSD, USB3 backup drive

---

## Step 1: Flash Ubuntu Server (On Your Dev Machine)

```bash
# Download Ubuntu Server 24.04 LTS ARM64
# https://ubuntu.com/download/raspberry-pi

# Use Raspberry Pi Imager or dd
# Raspberry Pi Imager recommended - it handles SSH setup automatically

# If using dd:
xzcat ubuntu-24.04-preinstalled-server-arm64+raspi.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

**In Raspberry Pi Imager:**
- Enable SSH
- Set username: `didac`
- Set hostname: `nexus`
- Configure WiFi (initial setup only, will add Tailscale later)

---

## Step 2: First Boot

```bash
# Find the Pi's IP (check your router or use)
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry"

# SSH in (default password if you set one, or key if configured)
ssh didac@<pi-ip>

# Update system
sudo apt update && sudo apt upgrade -y

# Set hostname if not done in imager
sudo hostnamectl set-hostname nexus

# Reboot
sudo reboot
```

---

## Step 3: Install Tailscale (Remote Access)

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate (opens browser on your dev machine)
sudo tailscale up

# Note down your Tailscale IP
tailscale ip -4
# Example: 100.x.x.x
```

**Now you can SSH via Tailscale from anywhere:**
```bash
ssh didac@100.x.x.x
```

---

## Step 4: Configure Storage

```bash
# Check connected drives
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINT

# You should see:
# - sda: Internal SATA SSD (system)
# - sdb: External USB3 (backup)

# Format backup drive (if needed)
sudo mkfs.ext4 -L backup_nexus /dev/sdb1

# Get UUID
sudo blkid /dev/sdb1
# Copy the UUID value

# Create mount point and add to fstab
sudo mkdir -p /mnt/backup
echo "UUID=<paste-uuid-here> /mnt/backup ext4 defaults,noatime,nofail 0 2" | sudo tee -a /etc/fstab

# Mount it
sudo mount -a

# Verify
df -h | grep backup

# Set ownership
sudo chown -R didac:didac /mnt/backup
```

---

## Step 5: Create Directory Structure

```bash
# Create standard directories
sudo mkdir -p /srv/{projects/{nexus,factsmind/{scripts,assets/{audio,fonts,images,logos}}},outputs,bin}
sudo chown -R didac:didac /srv

# Verify
ls -la /srv
ls -la /srv/projects/factsmind/assets/

# This creates:
# /srv/projects/nexus/           - Main repository
# /srv/projects/factsmind/        - FactsMind project
#   ├── scripts/                  - Python processing scripts
#   └── assets/                   - Permanent assets (Samba accessible)
#       ├── audio/                - Intro music, sound effects
#       ├── fonts/                - Typography files
#       ├── images/               - Permanent images
#       └── logos/                - Brand assets
# /srv/outputs/                   - Generated content (daily rotation)
# /srv/bin/                       - Static binaries (ffmpeg, ffprobe)
```

### Asset Management
See [Assets Management Guide](../operations/assets-management.md) for details on:
- How to access assets via Samba network share
- Uploading logos, fonts, audio files remotely
- Path mappings for n8n workflows

---

## Step 6: Install Docker

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sudo sh

# Add user to docker group
sudo usermod -aG docker didac

# Install docker compose plugin
sudo apt install -y docker-compose-plugin

# Logout and login again for group to take effect
exit
# SSH back in

# Verify (should work without sudo)
docker version
docker compose version
```

---

## Step 7: Deploy Nexus Repository

```bash
# Install git if not present
sudo apt install -y git

# Clone the Nexus infrastructure repository
cd /srv/projects
git clone <nexus-repo-url> nexus

# Clone application repositories (e.g., FactsMind)
git clone <factsmind-repo-url> factsmind

# Or if working locally, rsync from dev machine:
# rsync -avz --exclude='.git' ~/Projects/nexus/ didac@<tailscale-ip>:/srv/projects/nexus/
# rsync -avz --exclude='.git' ~/Projects/factsmind/ didac@<tailscale-ip>:/srv/projects/factsmind/
```

---

## Step 8: Configure Environment

```bash
cd /srv/docker

# Copy Docker Compose and env template
sudo mkdir -p /srv/docker
sudo cp infra/docker-compose.yml /srv/docker/
sudo cp infra/.env.example /srv/docker/.env

# Edit .env with strong passwords
sudo nano /srv/docker/.env

# Generate strong passwords (example)
openssl rand -base64 32
```

**Set these in .env:**
- `POSTGRES_PASSWORD` (database)
- `N8N_PASSWORD` (n8n login)
- `CODE_PASSWORD` (code-server)

---

## Step 9: Start Docker Stack

```bash
cd /srv/docker

# Start services
sudo docker compose up -d

# Watch logs (Ctrl+C to exit)
sudo docker compose logs -f

# Verify all containers running
sudo docker ps

# You should see:
# - nexus-postgres
# - nexus-n8n
# - nexus-redis
# - nexus-code-server
# - nexus-netdata
# - nexus-watchtower
```

---

## Step 10: Verify Services

Access via Tailscale IP or local IP:

**n8n:** `http://<pi-ip>:5678`
- Login with credentials from .env
- Should see empty workflow dashboard

**Netdata:** `http://<pi-ip>:19999`
- No login required (consider restricting access)
- Should see real-time system metrics

**code-server:** `http://<pi-ip>:8080`
- Login with CODE_PASSWORD
- Web-based VS Code

---

## Step 11: System Hardening

```bash
# Disable password SSH auth (SSH keys only)
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload sshd

# Configure journald to reduce disk writes
sudo tee /etc/systemd/journald.conf <<EOF
[Journal]
Storage=volatile
SystemMaxUse=50M
RuntimeMaxUse=50M
EOF
sudo systemctl restart systemd-journald

# Enable TRIM (SSD health)
sudo systemctl enable fstrim.timer

# Install and enable zram (compressed swap)
sudo apt install -y zram-tools
```

---

## Step 12: Health Checks

```bash
# Check for undervoltage (should return 0x0)
vcgencmd get_throttled

# Check temperature (should be <60°C idle)
vcgencmd measure_temp

# Check disk space
df -h

# Check Docker resource usage
docker stats --no-stream

# Verify PostgreSQL
docker exec -it nexus-postgres psql -U faceless -d n8n -c "SELECT version();"
```

---

## Troubleshooting

**Container won't start:**
```bash
docker compose logs <container-name>
```

**Permission denied errors:**
```bash
sudo chown -R didac:didac /srv
sudo chmod -R 755 /srv
```

**Out of memory:**
```bash
# Check memory usage
free -h

# Restart a service
docker compose restart <service-name>
```

**Can't access web interfaces:**
```bash
# Check if ports are listening
sudo netstat -tulpn | grep -E '(5678|8080|19999)'

# Check firewall (usually not enabled on Pi)
sudo ufw status
```

---

## Next Steps

Once Phase 0 is complete:
1. **Install Python dependencies** on the Pi or in a container
2. **Create first rendering script** (carousel.py)
3. **Build first n8n workflow** (manual trigger → generate → render → review)
4. **Test Instagram API access**

See `IMPLEMENTATION_ROADMAP.md` for Phase 1 and beyond.

---

## Useful Commands Reference

```bash
# Docker
docker compose up -d              # Start stack
docker compose down               # Stop stack
docker compose restart <service>  # Restart one service
docker compose logs -f <service>  # Follow logs
docker ps                         # List running containers
docker stats                      # Resource usage

# System
htop                              # Interactive process viewer
vcgencmd measure_temp             # Check temperature
df -h                             # Disk usage
free -h                           # Memory usage

# Tailscale
tailscale status                  # Connection status
tailscale ip -4                   # Your Tailscale IP

# Backups (once scripts are created)
/srv/scripts/backup_sync.sh       # Incremental backup
/srv/scripts/pg_backup.sh         # Database backup
```
