# Disaster Recovery

## Goal

Restore the complete homelab environment on a new Raspberry Pi / Debian / Ubuntu host after:

- SD card failure
- SSD failure
- corrupted OS
- accidental deletion
- hardware replacement

---

# What is backed up

The backup contains:

```text
~/homelab/data
```

Including:

- Pi-hole configuration
- NPM configuration
- Let's Encrypt certificates
- NetAlertX database
- Uptime Kuma data
- CrowdSec data
- Tailscale state
- Unbound configuration

The Git repository contains:

- docker-compose files
- scripts
- documentation
- automation

---

# Recovery Procedure

## 1. Install OS

Install:

- Raspberry Pi OS Lite
- Debian
- Ubuntu Server

Update system:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 2. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Logout/login after installation.

Verify:

```bash
docker --version
docker compose version
```

---

## 3. Clone repository

```bash
git clone git@github.com:YOUR_USER/homelab.git
cd homelab
```

---

## 4. Restore secrets

Create `.env` files manually.

Example:

```bash
cp .env.example .env
```


## `.env.example`

All secrets are stored in one root `.env` file.
Docker Compose commands must be executed with:

```bash
docker compose --env-file ../../.env up -d
```

Fill:

- passwords
- API tokens
- Telegram tokens
- Cloudflare credentials

---

## 5. Restore backup

Copy the selected backup directory to the new host.

Example:

```bash
scp -r backups/2026-05-20_03-15 rpi:~/homelab/backups/
```

Then run:

```bash
cd ~/homelab
./scripts/restore.sh
```

The restore script automatically:
- validates `.env`,
- creates required Docker networks,
- restores application data,
- starts services using `start-all.sh`.

---

## 6. Restore cron jobs

```bash
./scripts/install-cron.sh
```

Verify:

```bash
crontab -l
```

---

## 7. Verify DNS

Test Pi-hole:

```bash
dig google.com @127.0.0.1
```

Test Unbound:

```bash
dig google.com @127.0.0.1 -p 5335
```

Test local domain:

```bash
dig netalertx.example.com @127.0.0.1
```

Expected:

```text
192.168.0.101
```

---

## 8. Verify HTTPS

```bash
curl -Ik https://status.example.com
```

Expected:

```text
HTTP/2 200
```

or redirect from local service.

---

# Common Failure Scenarios

## DNS resolving public IP instead of local IP

Problem:

```text
nslookup service.example.com
-> Cloudflare public IP
```

Cause:

- router DNS cache
- device not using Pi-hole
- DHCP still using router DNS

Fix:

```bash
dig service.example.com @127.0.0.1
```

If correct locally:
- flush device DNS cache
- reconnect Wi-Fi
- renew DHCP lease

---

## Services unavailable after reboot

Check:

```bash
docker ps -a
```

Restart stack:

```bash
./scripts/start-all.sh
```

---

## NPM certificates missing

Check:

```bash
~/homelab/data/nginx-letsencrypt
```

Restore from backup.

---

## Tailscale offline

Check:

```bash
docker logs tailscale
```

Verify auth key and state files.

---

## CrowdSec not detecting logs

Verify mount:

```bash
docker exec -it crowdsec ls /var/log/nginx-proxy-manager
```

---

# Recovery Time Estimate

| Scenario | Estimated Time |
|---|---|
| Full OS reinstall | 20–40 min |
| SD card migration | 10–20 min |
| Restore from backup | 5–10 min |
| Full homelab recovery | ~1 hour |

---

# Important Notes

- Git repository alone is NOT enough
- `data/` backup is critical
- Keep offsite backup if possible
- Test recovery periodically

