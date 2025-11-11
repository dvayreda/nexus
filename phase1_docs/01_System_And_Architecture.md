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
/srv/projects/faceless_dev
/srv/projects/faceless_prod
/srv/outputs
/srv/temp
/srv/db
/srv/n8n_data
/mnt/backup
```
Set ownership to `didac`:
```bash
sudo mkdir -p /srv/projects/faceless_dev /srv/projects/faceless_prod /srv/outputs /srv/temp /srv/db /srv/n8n_data
sudo chown -R didac:didac /srv
```

---
## 8. Boot and service order
Recommendation: run Docker Compose under a systemd unit so the stack starts on boot after network online. Example unit is in Applications guide.

---
## 9. Quick verification checklist
- `ssh didac@nexus` works.
- `lsblk` shows `/dev/sda` and `/dev/sdb`.
- `df -h` shows `/mnt/backup` mounted.
- Docker installed and `docker ps` returns empty list initially.
