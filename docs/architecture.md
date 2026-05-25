# Architecture Diagram

```mermaid
flowchart TD
    Client[LAN / Wi-Fi Clients]
    Router[Router / DHCP]
    RPi[Raspberry Pi<br/>192.168.0.101]

    Client --> Router
    Router --> RPi

    subgraph RPi_Homelab[Raspberry Pi Homelab]
        PiHole[Pi-hole<br/>DNS :53<br/>Admin :8080]
        Unbound[Unbound<br/>DNS resolver :5335]
        NPM[Nginx Proxy Manager<br/>HTTP :80<br/>HTTPS :443<br/>Admin :8181]
        Kuma[Uptime Kuma<br/>:3001]
        NetAlertX[NetAlertX<br/>:20211]
        CrowdSec[CrowdSec<br/>NPM log analysis]
        Tailscale[Tailscale<br/>Remote VPN]
    end

    Client -->|DNS| PiHole
    PiHole -->|Upstream DNS| Unbound
    Unbound --> Internet[Internet]

    Client -->|HTTPS *.example.com| NPM

    NPM --> Kuma
    NPM --> NetAlertX
    NPM --> PiHole
    NPM --> NPMAdmin[NPM Admin UI]

    CrowdSec -->|reads logs| NPM
    Tailscale --> RPi
```

## DNS Flow

```text
Client
  -> Pi-hole 192.168.0.101:53
  -> Unbound 192.168.0.101:5335
  -> Internet
```

## HTTPS Flow

```text
Client
  -> https://service.example.com
  -> Nginx Proxy Manager
  -> internal service on Raspberry Pi
```

## Diagram
                         ┌──────────────────────┐
                         │      Internet         │
                         └──────────┬───────────┘
                                    │
                         ┌──────────▼───────────┐
                         │       Unbound         │
                         │     DNS :5335         │
                         └──────────▲───────────┘
                                    │
                         ┌──────────┴───────────┐
                         │       Pi-hole         │
                         │ DNS :53 / UI :8080    │
                         └──────────▲───────────┘
                                    │
┌──────────────────────┐            │
│   LAN / Wi-Fi Client │────────────┘
└──────────┬───────────┘
           │ HTTPS *.example.com
           ▼
┌────────────────────────────────────────────────────────────┐
│                 Raspberry Pi / Homelab                     │
│                    192.168.0.101                            │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Nginx Proxy Manager                     │  │
│  │        :80 / :443 / admin :8181                      │  │
│  └───────┬──────────────┬──────────────┬───────────────┘  │
│          │              │              │                  │
│          ▼              ▼              ▼                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │ Uptime Kuma │ │  NetAlertX  │ │   Pi-hole   │          │
│  │    :3001    │ │    :20211   │ │    :8080    │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
│                                                            │
│  ┌─────────────┐                 ┌─────────────┐          │
│  │  CrowdSec   │◄── NPM logs ────│  NPM logs   │          │
│  └─────────────┘                 └─────────────┘          │
│                                                            │
│  ┌─────────────┐                                          │
│  │  Tailscale  │  Remote VPN access                       │
│  └─────────────┘                                          │
└────────────────────────────────────────────────────────────┘
