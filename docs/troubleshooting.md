# Troubleshooting

# DNS Troubleshooting

## Verify Pi-hole DNS

```bash
dig google.com @127.0.0.1
```

Expected:

```text
SERVER: 127.0.0.1#53
```

---

## Verify Unbound

```bash
dig google.com @127.0.0.1 -p 5335
```

---

## Verify local DNS override

```bash
dig netalertx.example.com @127.0.0.1
```

Expected:

```text
192.168.0.101
```

---

## Problem: domain resolves public Cloudflare IP

Example:

```text
104.x.x.x
172.x.x.x
```

Cause:

- router DNS cache
- device using router DNS
- DHCP not updated

Verify resolver:

```bash
nslookup netalertx.example.com
```

If:

```text
Server: 192.168.0.1
```

then device is NOT using Pi-hole.

---

## Flush DNS cache

Linux:

```bash
sudo systemd-resolve --flush-caches
```

Windows:

```powershell
ipconfig /flushdns
```

Phone:
- disable/enable Wi-Fi

---

## Renew DHCP lease

Linux:

```bash
sudo nmcli con down "Wired connection 1"
sudo nmcli con up "Wired connection 1"
```

---

# SSL Troubleshooting

## Verify reverse proxy

```bash
curl -Ik --resolve status.example.com:443:192.168.0.101 \
https://status.example.com
```

Expected:

```text
server: openresty
```

---

## Problem: Cloudflare response instead of local service

Example:

```text
server: cloudflare
```

Cause:
- DNS bypassing Pi-hole
- domain resolving public IP

---

## Verify NPM container

```bash
docker logs nginx-proxy-manager
```

---

## Verify SSL certificates

```bash
ls ~/homelab/data/nginx-letsencrypt
```

---

## Verify local HTTPS

```bash
curl -Ik https://service.example.com
```

---

# Tailscale Troubleshooting

## Verify status

```bash
docker exec -it tailscale tailscale status
```

---

## Verify logs

```bash
docker logs tailscale
```

---

## Problem: tailscale up requires flags

Cause:
Container restarted with missing parameters.

Fix:
Use all required flags again.

Example:

```bash
tailscale up \
  --accept-dns=false \
  --hostname=rpi-tailscale \
  --advertise-routes=192.168.0.0/24
```

---

## Problem: cannot access local services through Tailscale

Verify:

- service running
- reverse proxy working
- DNS resolution
- firewall
- subnet routes advertised

---

## Verify subnet routes

```bash
docker logs tailscale | grep advertise-routes
```

---

## Verify remote access

Example:

```bash
curl http://100.x.x.x:3001
```

---

# Docker Troubleshooting

## Verify all containers

```bash
docker ps
```

---

## Verify health

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

---

## Restart all services

```bash
./scripts/stop-all.sh
./scripts/start-all.sh
```

---

# Backup Troubleshooting

## Verify backups

```bash
ls ~/homelab/backups
```

---

## Run manual backup

```bash
./scripts/backup.sh
```

---

## Verify backup content

```bash
tar -tzf backup.tar.gz | head
```
