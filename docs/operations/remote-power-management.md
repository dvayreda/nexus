# Remote Power Management

**Version:** 1.0
**Last Updated:** 2025-11-20
**Maintainer:** didac

---

## Overview

This document describes how to remotely manage Nexus power when away from home for extended periods (4-5 days). The system includes multiple layers of protection to prevent freezes and enable remote recovery.

## Problem Statement

During intensive operations (e.g., FFmpeg video rendering), the Raspberry Pi can run out of memory and freeze completely, making it unresponsive to SSH and requiring physical power cycle. When away from home, this results in extended downtime.

## Multi-Layer Protection System

### Layer 1: Memory Watchdog (Software)
**What:** Systemd service that monitors memory every 30 seconds
**Action:**
- If available memory < 200MB → Stop n8n container
- If available memory < 100MB → Trigger system reboot

**Configuration:**
- Service: `/etc/systemd/system/memory-watchdog.service`
- Timer: `/etc/systemd/system/memory-watchdog.timer`
- Script: `/usr/local/bin/memory-watchdog.sh`

**Status Check:**
```bash
systemctl status memory-watchdog.timer
sudo /usr/local/bin/memory-watchdog.sh  # Manual test
journalctl -u memory-watchdog -n 20     # View logs
```

### Layer 2: Hardware Watchdog (Built-in Pi)
**What:** Raspberry Pi BCM2835 hardware watchdog timer
**Action:** Force reboot if system freezes for > 60 seconds

**Configuration:**
- Kernel module: `bcm2835_wdt` (loaded at boot)
- Systemd config: `/etc/systemd/system.conf.d/watchdog.conf`
- Timeout: 60 seconds

**Status Check:**
```bash
systemctl show | grep -i watchdog
ls -l /dev/watchdog*
```

**How it works:**
1. Systemd sends heartbeat to `/dev/watchdog` every 30 seconds
2. If heartbeat stops (system frozen), hardware timer expires after 60s
3. Hardware forces immediate reboot

### Layer 3: Smart WiFi Plug (Optional - Recommended)
**What:** Remote-controlled power outlet via smartphone app
**Action:** Complete power cycle from anywhere in the world

**Recommended Products:**

#### TP-Link Kasa Smart Plug Mini (HS105)
- **Price:** ~$15-20
- **App:** Kasa Smart (iOS/Android)
- **Features:**
  - Remote on/off via internet
  - Schedules (auto-reboot weekly)
  - Energy monitoring
  - No hub required
- **Setup:** Plug Pi into smart plug, connect plug to WiFi via app

#### Shelly Plug S
- **Price:** ~$15-25
- **App:** Shelly Cloud (iOS/Android)
- **Features:**
  - Remote control
  - Webhooks/API support
  - Local control (works without internet)
  - Energy monitoring
- **Advanced:** Can integrate with Tailscale for secure remote access

#### Installation Steps
1. Purchase smart plug (TP-Link Kasa or Shelly recommended)
2. Connect plug to home WiFi using manufacturer's app
3. Create account in app for remote access
4. Plug Pi power supply into smart plug
5. Test remote power cycle from app

#### Usage When Away
**Via Smartphone:**
1. Open Kasa/Shelly app
2. Find "Nexus" plug
3. Turn OFF → Wait 10 seconds → Turn ON
4. Wait 2-3 minutes for Pi to boot
5. Test SSH connection: `ssh didac@100.122.207.23`

**Scheduled Reboots (Optional):**
- Set weekly schedule in app (e.g., Sunday 3 AM)
- Automatically power cycles Pi to prevent issues

## Emergency Recovery Procedure

### Scenario: System Unresponsive While Away

**Step 1: Verify Issue**
```bash
# Try ping
ping 100.122.207.23

# Try SSH
ssh didac@100.122.207.23

# Check Tailscale status
tailscale status | grep nexus
```

**Step 2: Wait for Hardware Watchdog (5 minutes)**
If system is frozen, hardware watchdog should trigger reboot within 60 seconds. Wait 5 minutes total for boot.

**Step 3: Smart Plug Power Cycle (If available)**
1. Open smart plug app on smartphone
2. Turn OFF plug
3. Wait 10 seconds
4. Turn ON plug
5. Wait 3 minutes for full boot
6. Retry SSH

**Step 4: Check Logs After Recovery**
```bash
# Check what caused the issue
ssh didac@100.122.207.23
sudo journalctl -b -1 --no-pager | tail -100  # Previous boot
sudo journalctl -u memory-watchdog -n 50      # Memory watchdog logs
free -h                                        # Current memory status
docker ps -a                                   # Container status
```

## System Resilience Features

### Swap Space: 4GB
**Purpose:** Emergency memory overflow
**Location:** `/swapfile`
**Verification:**
```bash
swapon --show
free -h
```

### Persistent Logging
**Purpose:** Capture crash data for analysis
**Location:** `/var/log/journal/`
**Configuration:** `/etc/systemd/journald.conf.d/persistent.conf`
**Retention:** 7 days, max 500MB

**View logs after crash:**
```bash
# List available boots
sudo journalctl --list-boots

# View previous boot logs
sudo journalctl -b -1 --no-pager

# Search for crashes
sudo journalctl -b -1 | grep -E "oom|kill|panic|freeze"
```

## Maintenance Schedule

### Weekly (Automated)
- Smart plug auto-reboot (if configured)
- Memory watchdog monitoring (continuous)
- Hardware watchdog active (continuous)

### Monthly (Manual)
```bash
# Check memory watchdog logs
journalctl -u memory-watchdog --since "1 month ago"

# Check for hardware watchdog triggers
journalctl | grep -i watchdog | tail -20

# Verify swap usage
free -h
```

### After Each Freeze Event
1. Check persistent logs for root cause
2. Verify memory watchdog logs
3. Check if hardware watchdog triggered
4. Analyze what process consumed memory
5. Adjust thresholds if needed

## Cost Summary

| Component | Cost | Status |
|-----------|------|--------|
| Memory Watchdog | FREE | ✅ Active |
| Hardware Watchdog | FREE | ✅ Active |
| Persistent Logging | FREE | ✅ Active |
| 4GB Swap | FREE | ✅ Active |
| Smart Plug | $15-25 | ⚠️ Optional |

**Total Required Investment:** $0 (all protections are free/built-in)
**Recommended Investment:** $15-25 (add smart plug for complete remote control)

## Smart Plug Purchase Links

### Amazon (US)
- TP-Link Kasa HS105: Search "TP-Link Kasa Smart Plug Mini"
- Shelly Plug S: Search "Shelly Plug S Smart WiFi"

### Amazon (Spain/EU)
- TP-Link Kasa: "Enchufe Inteligente TP-Link Kasa"
- Shelly Plug S: "Shelly Plug S Enchufe Inteligente"

## Tailscale Integration (Advanced)

If using Shelly Plug with local API:
```bash
# Power cycle via Shelly local API (when on Tailscale network)
curl http://192.168.1.XXX/relay/0?turn=off
sleep 10
curl http://192.168.1.XXX/relay/0?turn=on
```

## Related Documentation

- [Maintenance Guide](maintenance.md) - Regular system checks
- [System Reference](../architecture/system-reference.md) - Hardware specs
- [Assets Management](assets-management.md) - Samba access when system is up

## Troubleshooting

### Memory Watchdog Not Running
```bash
systemctl status memory-watchdog.timer
sudo systemctl restart memory-watchdog.timer
```

### Hardware Watchdog Not Enabled
```bash
systemctl show | grep RuntimeWatchdogUSec
# Should show: RuntimeWatchdogUSec=1min
sudo systemctl daemon-reexec
```

### Smart Plug Not Connecting
1. Ensure plug is connected to 2.4GHz WiFi (not 5GHz)
2. Ensure plug has internet access for remote control
3. Restart router if app shows "offline"

## Changelog

- **2025-11-20:** Initial creation after system freeze incident. Added multi-layer protection system (memory watchdog, hardware watchdog, smart plug documentation).
