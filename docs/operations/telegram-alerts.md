# Telegram Alert Setup for Nexus

**Purpose:** Receive critical alerts from Nexus monitoring system via Telegram

## Overview

Nexus watchdog script can send alerts via Telegram when critical issues are detected:
- Services down after multiple restart attempts
- Disk usage > 90%
- Memory pressure (swap > 80%)
- Service restart notifications

## Setup Instructions

### Step 1: Create Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow prompts to name your bot (e.g., "Nexus Alerts Bot")
4. Save the **bot token** provided (format: `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Step 2: Get Your Chat ID

1. Send a message to your bot (any message)
2. Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Replace `<YOUR_BOT_TOKEN>` with your actual token
3. Look for `"chat":{"id":123456789,...}`
4. Save your **chat ID** (the number after `"id":`)

### Step 3: Configure on Raspberry Pi

Add Telegram credentials to your shell environment:

```bash
# SSH to Nexus
~/ssh-nexus

# Edit .bashrc to add Telegram variables
echo 'export TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"' >> ~/.bashrc
echo 'export TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"' >> ~/.bashrc

# Reload environment
source ~/.bashrc

# Verify
echo $TELEGRAM_BOT_TOKEN
echo $TELEGRAM_CHAT_ID
```

### Step 4: Test Alert

Run watchdog manually to test:

```bash
~/ssh-nexus '~/nexus_watchdog.sh --dry-run'
```

To send a test alert, temporarily stop a service and run watchdog:

```bash
# Stop n8n temporarily
~/ssh-nexus 'docker stop nexus-n8n'

# Run watchdog (will detect and restart)
~/ssh-nexus '~/nexus_watchdog.sh'

# You should receive a Telegram alert!
```

## Alert Types

### Critical (🔴)
- Service failed 3+ times in 1 hour
- Disk usage > 95%
- Memory pressure critical (swap > 90%)

### Warning (⚠️)
- Service down and restarting
- Service restart failed
- Disk usage > 90%
- Memory pressure high (swap > 80%)

### Info (ℹ️)
- Service restarted successfully

## Alert Format

```
[NEXUS] 🔴 CRITICAL: Service nexus-n8n has failed 3 times in 1 hour. Manual intervention required!
```

```
[NEXUS] ⚠️  WARNING: Service nexus-n8n was down and has been restarted successfully
```

## Troubleshooting

### Not receiving alerts?

**Check bot token and chat ID:**
```bash
~/ssh-nexus 'echo $TELEGRAM_BOT_TOKEN'
~/ssh-nexus 'echo $TELEGRAM_CHAT_ID'
```

**Test Telegram API directly:**
```bash
~/ssh-nexus 'curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test%20from%20Nexus"'
```

**Check watchdog logs:**
```bash
~/ssh-nexus 'tail -n 50 /var/log/nexus_watchdog.log'
```

### Too many alerts?

Alerts are rate-limited:
- Same incident type: Once per hour
- Disk elevated: Once per 6 hours

To adjust thresholds, edit `~/nexus_watchdog.sh` on the Pi.

## Security Notes

- Bot token is sensitive - treat like a password
- Chat ID limits who can receive alerts
- Alerts contain system status info - keep chat private
- Consider using Telegram's secret chats for extra security

## Disabling Alerts

To temporarily disable Telegram alerts without removing configuration:

```bash
~/ssh-nexus 'unset TELEGRAM_BOT_TOKEN'
```

Watchdog will continue running but won't send alerts.

To permanently disable, remove from `.bashrc`:
```bash
~/ssh-nexus 'sed -i "/TELEGRAM_/d" ~/.bashrc'
```

## Related Documentation

- [Watchdog Script](../../scripts/pi/nexus_watchdog.sh) - Source code
- [Monitoring Database](../architecture/monitoring-database.md) - Incident logging
- [ROADMAP.md](../../ROADMAP.md) - Phase 1: Stability Foundation

---

**Last updated:** 2025-01 (Initial Telegram alerts implementation)
