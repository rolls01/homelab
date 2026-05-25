# Adding New Service

## Goal

Add a new Docker service to the homelab in a consistent and maintainable way.

---

# Recommended Structure

Create:

```text
compose/<service-name>/
```

Example:

```text
compose/grafana/
```

---

# 1. Create Compose Directory

```bash
mkdir -p ~/homelab/compose/grafana
cd ~/homelab/compose/grafana
```

---

# 2. Create Data Directory

```bash
mkdir -p ~/homelab/data/grafana
```

---

# 3. Create docker-compose.yml

Example:

```yaml
services:
  grafana:
    image: grafana/grafana:latest

    container_name: grafana

    restart: unless-stopped

    ports:
      - "3000:3000"

    volumes:
      - ../../data/grafana:/var/lib/grafana

    networks:
      - homelab

networks:
  homelab:
    external: true
```

---

# 4. Start Service

```bash
docker compose --env-file ../../.env up -d
```

Verify:

```bash
docker ps
```

---

# 5. Add Reverse Proxy

In Nginx Proxy Manager:

| Setting | Value |
|---|---|
| Domain | grafana.example.com |
| Forward Hostname | 192.168.0.101 |
| Forward Port | 3000 |

Enable:

- SSL
- Force SSL
- HTTP/2

---

# 6. Add Local DNS

In Pi-hole:

```text
Local DNS Records
```

Add:

```text
grafana.example.com -> 192.168.0.101
```

---

# 7. Test

```bash
curl -Ik --resolve grafana.example.com:443:192.168.0.101 \
https://grafana.example.com
```

---

# 8. Add Backup Support

Update:

```text
scripts/backup.sh
```

Add:

```bash
backup_folder "grafana" "$HOMELAB_DIR/data/grafana"
```

---

# 9. Add Healthcheck

Example:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:3000 >/dev/null || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
```

---

# 10. Add Documentation

Update:

- docs/services.md
- docs/network.md
- architecture diagram
- README if needed

---

# Recommended Rules

## Use persistent storage

Always mount:

```text
../../data/<service>
```

---

## Use restart policy

```yaml
restart: unless-stopped
```

---

## Prefer reverse proxy over direct ports

Preferred:

```text
https://service.example.com
```

instead of:

```text
http://192.168.0.101:3000
```

---

## Prefer internal Docker networks

Avoid exposing admin ports to entire LAN unless necessary.

---

# Verification Checklist

| Check | Status |
|---|---|
| Container running | ☐ |
| Healthcheck healthy | ☐ |
| Reverse proxy works | ☐ |
| SSL works | ☐ |
| Local DNS works | ☐ |
| Backup configured | ☐ |
| Docs updated | ☐ |

