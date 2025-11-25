# Tailscale MTU Configuration

## Problem

SSH connections timeout after 60 seconds when connecting from WSL to Raspberry Pi over Tailscale on the same physical LAN.

**Error:** Connection hangs at SSH key exchange (`SSH2_MSG_KEX_ECDH_REPLY`)

## Root Cause

When Tailscale peers are on the same physical LAN, they route traffic directly via the local network IP instead of through DERP relays. If the MTU (Maximum Transmission Unit) is set too low (1280 bytes, common WSL/Pi default), SSH's key exchange packets get fragmented. Fragment reassembly fails on direct LAN paths, causing timeouts.

## Solution

Set MTU to 1500 bytes on both WSL and Raspberry Pi to allow full-size packets without fragmentation.

### WSL Configuration

Add boot command to `/etc/wsl.conf`:

```ini
[boot]
command=/usr/local/bin/wsl-mtu-fix.sh
```

Create `/usr/local/bin/wsl-mtu-fix.sh`:

```bash
#!/bin/bash
# Set MTU to 1500 for Tailscale connectivity
ip link set dev eth0 mtu 1500 2>/dev/null || true
```

Make it executable:
```bash
sudo chmod +x /usr/local/bin/wsl-mtu-fix.sh
```

**Note:** Requires WSL reboot to take effect.

### Raspberry Pi Configuration

Create systemd service `/etc/systemd/system/mtu-fix.service`:

```ini
[Unit]
Description=Set Tailscale MTU to 1500
After=network.target
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mtu-fix.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Create `/usr/local/bin/mtu-fix.sh`:

```bash
#!/bin/bash
# Set MTU to 1500 for Tailscale connectivity
ip link set dev eth0 mtu 1500
```

Make it executable and enable:

```bash
sudo chmod +x /usr/local/bin/mtu-fix.sh
sudo systemctl daemon-reload
sudo systemctl enable mtu-fix.service
sudo systemctl start mtu-fix.service
```

Verify it's running:
```bash
systemctl status mtu-fix.service
```

## Verification

Check current MTU settings:

```bash
# WSL
ip link show dev eth0 | grep mtu

# Pi
ssh nexus "ip link show dev eth0 | grep mtu"
```

Both should show: `mtu 1500`

Test SSH connection:
```bash
ssh nexus "echo 'Connection successful!'"
```

## Troubleshooting

**SSH still timing out?**
- Verify MTU is 1500: `ip link show dev eth0`
- If still 1280, manually set: `sudo ip link set dev eth0 mtu 1500`
- Check Tailscale connectivity: `tailscale ping nexus`
- View SSH handshake: `ssh -vvv nexus` (should not hang at `SSH2_MSG_KEX_ECDH_REPLY`)

**Settings revert after reboot?**
- WSL: Restart WSL (`wsl --terminate Ubuntu`) to trigger boot command
- Pi: Verify service is enabled: `sudo systemctl status mtu-fix.service`

## Related

- [Tailscale on same network](https://tailscale.com/kb/1118/subnets/)
- [SSH key exchange algorithms](https://man.openbsd.org/ssh_config#KexAlgorithms)
