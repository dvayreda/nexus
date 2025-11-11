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
