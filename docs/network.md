# Network

## Host

Raspberry Pi

- LAN IP: `192.168.0.101`
- Main homelab path: ~/homelab

## Core services

| Service | Local address | Notes |
|---|---:|---|
| Pi-hole | `192.168.0.101:53`, `192.168.0.101:8080` | DNS + web admin |
| Unbound | `192.168.0.101:5335` | Upstream DNS for Pi-hole |
| Nginx Proxy Manager | `192.168.0.101:80`, `443`, `8181` | Reverse proxy + SSL |
| Uptime Kuma | `192.168.0.101:3001` | Monitoring |
| NetAlertX | `192.168.0.101:20211` | Network discovery |
| Tailscale | host network | Remote VPN access |
| CrowdSec | internal | Parses NPM logs |

## Proxy hosts

| Domain | Destination | SSL | Status |
|---|---|---|---|
| `status.example.com` | `http://192.168.0.101:3001` | Let's Encrypt | Online |
| `netalertx.example.com` | `http://192.168.0.101:20211` | Let's Encrypt | Online |
| `nginx.example.com` | `http://192.168.0.101:8181` | Let's Encrypt | Online |
| `pihole.example.com` | `http://192.168.0.101:8080` | Let's Encrypt | Online |

## DNS flow

```text
Client
  -> Pi-hole 192.168.0.101:53
  -> Unbound 192.168.0.101:5335
  -> Internet DNS resolution
```

