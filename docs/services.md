# Homelab Services

## Overview

| Service | Purpose | Port | Data path | Notes |
|---|---|---:|---|---|
| Pi-hole | Local DNS, ad blocking | 53, 8080 | `data/pihole/etc-pihole` | Main DNS for LAN |
| Unbound | Recursive DNS resolver | 5335 | `data/unbound` | Upstream for Pi-hole |
| Nginx Proxy Manager | Reverse proxy + SSL | 80, 443, 8181 | `data/nginx`, `data/nginx-letsencrypt` | Local HTTPS domains |
| Uptime Kuma | Monitoring | 3001 | `data/uptime-kuma` | Service status dashboard |
| NetAlertX | Network discovery | 20211 | `data/netalertx` | LAN device monitoring |
| Tailscale | Remote VPN access | host network | `data/tailscale` | Secure remote access |
| CrowdSec | Security monitoring | internal | `data/crowdsec` | Parses NPM logs |

## DNS Flow

```text
Client
  -> Pi-hole :53
  -> Unbound :5335
  -> Internet
```

