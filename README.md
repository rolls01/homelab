# Homelab

![Last commit](https://img.shields.io/github/last-commit/rolls01/homelab)
![License](https://img.shields.io/github/license/rolls01/homelab)

Production-grade self-hosted infrastructure on a Raspberry Pi 4. Zero public ports — all external access via Tailscale VPN or HTTPS with wildcard Let's Encrypt certificates. Built to survive a full SD card failure: automated daily backups, one-command restore, and Telegram alerts when anything goes wrong.

---

## What makes this different

- **Pre-update backup** — `update.sh` runs `backup.sh` first; a failed backup aborts the update
- **Stateful monitoring** — `monitor.sh` fires Telegram alerts exactly once per event (disk, temp, unhealthy container, kernel reboot required) and sends a recovery message when resolved
- **Firewall with Docker awareness** — `setup-firewall.sh` installs a systemd service that rewrites `DOCKER-USER` iptables rules after every Docker restart; public ports (80/443) open, admin ports (8080/8181) LAN-only
- **Per-service update errors** — each service is updated independently; failures are collected and reported without stopping other services
- **Local DNS in git** — Pi-hole custom DNS records versioned in `config/` (gitignored real file, committed `.example`)

---

## Daily Telegram report

```
📊 RPi Homelab Report

🖥 Host: rpi
⏱ Uptime: up 3 days, 14 hours
🌡 Temp: 47.2°C
⚙ Load: 0.18, 0.22, 0.20
💾 RAM: 1.2G/3.7G (2.1G free)
📀 Disk /: 8.1G/29G (28%)
🏠 Disk home: 8.1G/29G (28%)

🌐 Network
eth0: 192.168.0.101
Latency: 12.4 ms
System DNS: 127.0.0.1

🐳 Docker (7 running)
• pihole — Up 3 days (healthy)
• unbound — Up 3 days (healthy)
• nginx-proxy-manager — Up 3 days (healthy)
• uptime-kuma — Up 3 days (healthy)
• NetAlertX — Up 3 days (healthy)
• crowdsec — Up 3 days (healthy)
• tailscale — Up 3 days (healthy)

🧩 Services
🟢 Pi-hole: healthy
🟢 Unbound: healthy
🟢 NPM: healthy
🟢 Uptime Kuma: healthy
🟢 NetAlertX: healthy
🟢 CrowdSec: healthy
🟢 Tailscale: healthy

🔎 DNS
Pi-hole: 142.250.74.46
Unbound: 142.250.74.46

📡 NetAlertX
Devices: 24

💾 Backup
Last: /home/pi/homelab/backups/2026-05-25
Size: 142M
```

---

## Services

| Service | Role | Port |
|---------|------|------|
| [Pi-hole](https://pi-hole.net) | DNS ad-blocking | :53 / :8080 |
| [Unbound](https://nlnetlabs.nl/projects/unbound/) | Recursive DNS resolver | :5335 |
| [Nginx Proxy Manager](https://nginxproxymanager.com) | Reverse proxy + SSL | :80/:443 |
| [Uptime Kuma](https://github.com/louislam/uptime-kuma) | Service monitoring | :3001 |
| [NetAlertX](https://github.com/jokob-sk/NetAlertX) | Network device scanner | :20211 |
| [CrowdSec](https://crowdsec.net) | Intrusion detection | — |
| [Tailscale](https://tailscale.com) | VPN remote access | — |

---

## Hardware

| Component | Spec |
|-----------|------|
| Board     | Raspberry Pi 4 Model B |
| RAM       | 4 GB |
| Storage   | SD card / USB SSD |
| Network   | Ethernet |
| Power     | Official RPi PSU |

---

## Architecture

```text
Client
  -> Pi-hole (DNS :53)
  -> Unbound (recursive resolver :5335)
  -> Internet

HTTPS *.yourdomain.com
  -> Nginx Proxy Manager (:80/:443)
  -> internal services
```

See [docs/architecture.md](docs/architecture.md) for a full Mermaid diagram.

---

## Repository Structure

```text
compose/   -> docker compose files per service
config/    -> versioned config (docker daemon, Pi-hole DNS template)
data/      -> runtime persistent data (NOT in git)
docs/      -> architecture, networking, disaster recovery, troubleshooting
scripts/   -> automation (update, backup, monitor, report, firewall)
backups/   -> local backups (NOT in git)
```

---

## Initial Setup

### 1. Provision OS (fresh install only)

```bash
git clone git@github.com:YOUR_USER/homelab.git ~/homelab
cd ~/homelab
sudo ./provision.sh
```

Installs Docker, configures hostname/timezone/SSH/swap, applies daemon config.

### 2. Configure domain

Replace `example.com` across all docs with your actual domain:

```bash
find docs/ -name "*.md" -exec sed -i 's/example\.com/yourdomain.com/g' {} +
```

### 3. Create `.env`

```bash
cp .env.example .env
nano .env   # comments in the file explain each variable and its scope
```

### 4. Configure Pi-hole local DNS

```bash
cp config/pihole-custom-dns.list.example config/pihole-custom-dns.list
nano config/pihole-custom-dns.list
```

---

## Day-to-day

```bash
make status        # show running containers
make update        # backup → pull new images → restart
make backup        # manual backup
make monitor       # run health/disk/temp check now
make report        # send Telegram report now
make check-updates # check Docker Hub for new versions
```

---

## Disaster Recovery

1. Install fresh Raspberry Pi OS
2. `git clone ... ~/homelab && cd ~/homelab`
3. `sudo ./provision.sh`
4. Restore `.env` and `config/pihole-custom-dns.list`
5. `./scripts/restore.sh`
6. `./scripts/install-cron.sh`
7. Verify: `make status`

See [docs/disaster-recovery.md](docs/disaster-recovery.md) for RTO table and step-by-step verification.

---

## SSL / Certificates

Let's Encrypt wildcard certificates via Nginx Proxy Manager + Cloudflare DNS-01 challenge. Auto-renewal every 60 days. If `CF_API_TOKEN` expires, renew in Cloudflare dashboard and update the token in NPM web UI.

---

## What's not in this repo

| Item | Location |
|------|----------|
| Secrets / `.env` | local only |
| Runtime data | `~/homelab/data/` |
| Certificates | managed by NPM |
| Backups | `~/homelab/backups/` |
| Local DNS records | `config/pihole-custom-dns.list` (gitignored) |
