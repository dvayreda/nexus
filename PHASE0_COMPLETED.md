# Phase 0 Setup - COMPLETED ✅

**Date:** 2025-11-12
**Status:** Production Ready
**Deployment:** Raspberry Pi 4 (8GB) with NASPi V2.0 Case

---

## What Was Accomplished

### Hardware Configuration
- **Board:** Raspberry Pi 4 (8GB RAM)
- **Case:** NASPi V2.0 with SATA bay
- **System Storage:** 465GB SATA SSD (internal)
- **Backup Storage:** 500GB HDD (USB3)
- **Network:** WiFi (2.4GHz) + Tailscale VPN
  - ⚠️ **CRITICAL:** Aluminum case blocks WiFi signal - ethernet cable required for reliable operation

### Operating System
- **OS:** Ubuntu Server 22.04.5 LTS (ARM64)
- **Kernel:** 6.8.0-1031-raspi
- **Boot Device:** Internal SATA SSD (cloned from SD card)
- **Available Storage:** 458GB system + 465GB backup

### Installed Software
- **Docker:** 29.0.0 with Compose plugin
- **Tailscale:** 1.90.6 (IP: 100.91.192.97)
- **Python:** 3.10 with RPi.GPIO for hardware control
- **Git:** Configured for development

### Services Configured (Auto-Start)
1. **Docker** - Container runtime
2. **naspi-fan** - Temperature-based PWM fan control (GPIO 18)
3. **naspi-power** - Power button monitoring for safe shutdown (GPIO 6)
4. **tailscaled** - Secure remote access VPN

### System Hardening Applied
- **journald** - Volatile storage (RAM only, reduces SSD wear)
- **TRIM** - Weekly SSD maintenance via fstrim.timer
- **zram** - Compressed RAM swap for better memory utilization
- **Backup drive** - Auto-mounts at /mnt/backup via fstab

### Directory Structure
```
/srv/
├── projects/
│   └── nexus/          # This repository
├── db/
│   └── postgres/       # PostgreSQL data (for Phase 1)
├── n8n_data/           # n8n workflows (for Phase 1)
├── outputs/            # Generated content
├── docker/             # Docker Compose files
└── scripts/            # Operational scripts

/mnt/backup/            # 500GB backup drive
```

---

## Known Issues & Workarounds

### 1. NASPi Case WiFi Blocking
**Problem:** Aluminum case acts as Faraday cage, blocks 2.4GHz WiFi
**Impact:** Network drops when case is closed
**Workaround:** Keep case lid open until ethernet cable arrives
**Permanent Fix:** Use ethernet cable (strongly recommended)

### 2. Ubuntu 24.04 Network Bug
**Problem:** Ubuntu 24.04 has known bug breaking eth0/wlan0 after apt upgrade
**Solution:** Used Ubuntu 22.04 LTS instead (stable, supported until 2027)

### 3. NASPi XScript Incompatibility
**Problem:** Official NASPi scripts expect Raspberry Pi OS paths
**Solution:** Created custom Python scripts using RPi.GPIO for fan/power control

---

## SSH Access

**Local Network:**
```bash
ssh -i ~/.ssh/id_ed25519_nexus didac@192.168.1.148
```

**Tailscale (from anywhere):**
```bash
ssh -i ~/.ssh/id_ed25519_nexus didac@100.91.192.97
```

**Tmux Session:**
```bash
# Attach to shared session
tmux attach -t nexus-setup

# Detach: Ctrl+b, then d
```

---

## Next Steps (Phase 1)

1. **Get Ethernet Cable**
   - Cat5e/Cat6, any length
   - Plug into router, close NASPi case permanently

2. **Configure Secrets**
   ```bash
   cd /srv/projects/nexus/infra
   cp .env.example /srv/docker/.env
   # Edit /srv/docker/.env with API keys
   ```

3. **Deploy Docker Stack**
   ```bash
   cd /srv/docker
   docker compose up -d
   ```

4. **Access Services**
   - n8n: http://100.91.192.97:5678
   - code-server: http://100.91.92.97:8080
   - Netdata: http://100.91.192.97:19999

5. **Configure Backups**
   - Set up automated backup script
   - Test disaster recovery procedure

---

## Temperature & Performance

**Idle State:**
- CPU Temp: ~45-50°C
- Fan Speed: 0-25% (quiet)
- RAM Usage: ~500MB / 8GB

**Under Load:**
- CPU Temp: ~60-65°C
- Fan Speed: 75-100% (audible but acceptable)
- Docker headroom: 7.5GB available

**Fan Control Thresholds:**
- 60°C+: 100% speed
- 55-60°C: 75% speed
- 50-55°C: 50% speed
- 45-50°C: 25% speed
- <45°C: Off (silent)

---

## Lessons Learned

1. **Always test network after system upgrades** - Ubuntu 24.04 broke networking
2. **Metal cases need ethernet** - WiFi unreliable with aluminum shielding
3. **Keep case open during setup** - Avoids WiFi dropouts
4. **Use SD card for initial install, then clone to SSD** - Faster than direct SSD install
5. **Test NASPi controls immediately** - Fan silence = overheating risk

---

## System Health Check Commands

```bash
# Check all services
systemctl is-active docker naspi-fan naspi-power tailscaled

# Temperature
vcgencmd measure_temp

# Storage
df -h | grep -E "sda2|sdb1"

# Docker status
docker ps

# Backup drive
ls -lh /mnt/backup/

# Network
ip addr show wlan0
tailscale status
```

---

## Contact & Support

- **Project Owner:** selto (didac@nexus)
- **Setup Date:** 2025-11-12
- **Claude Code Session:** Phase 0 Infrastructure Setup
- **Repository:** https://github.com/dvayreda/nexus

---

**Status:** ✅ Phase 0 Complete - Ready for Phase 1 Docker Deployment
