#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
TELEGRAM_SCRIPT="$SCRIPT_DIR/telegram.sh"

LOCAL_TEST_DOMAIN="${LOCAL_TEST_DOMAIN:-}"
DISK_ALERT_THRESHOLD="${DISK_ALERT_THRESHOLD:-80}"
TEMP_ALERT_THRESHOLD="${TEMP_ALERT_THRESHOLD:-70}"

safe() {
  bash -c "$1" 2>/dev/null || echo "N/A"
}

health_icon() {
  case "${1:-}" in
    healthy)   echo "🟢" ;;
    unhealthy) echo "🔴" ;;
    starting)  echo "🟡" ;;
    *)         echo "⚪" ;;
  esac
}

# --- System ---
TEMP_RAW=$(safe "vcgencmd measure_temp | grep -oP '[0-9]+\\.[0-9]+'")
TEMP_INT=0; [[ "$TEMP_RAW" =~ ^([0-9]+) ]] && TEMP_INT="${BASH_REMATCH[1]}"
TEMP="${TEMP_RAW}°C$([ "$TEMP_INT" -ge "$TEMP_ALERT_THRESHOLD" ] && echo ' ⚠️' || true)"

UPTIME=$(safe "uptime -p")
LOAD=$(safe "uptime | awk -F'load average:' '{print \$2}' | xargs")
RAM=$(safe "free -h | awk '/Mem:/ {print \$3 \"/\" \$2 \" (\" \$4 \" free)\"}'")

DISK_ROOT_RAW=$(safe "df -h / | awk 'NR==2 {print \$3 \"/\" \$2 \" (\" \$5 \")\"}'")
DISK_ROOT_PCT=$(safe "df / | awk 'NR==2 {gsub(/%/,\"\"); print \$5}'")
DISK_ROOT="${DISK_ROOT_RAW}$([ "${DISK_ROOT_PCT:-0}" -ge "$DISK_ALERT_THRESHOLD" ] && echo ' ⚠️' || true)"

DISK_HOME_RAW=$(safe "df -h \$HOME | awk 'NR==2 {print \$3 \"/\" \$2 \" (\" \$5 \")\"}'")
DISK_HOME_PCT=$(safe "df \$HOME | awk 'NR==2 {gsub(/%/,\"\"); print \$5}'")
DISK_HOME="${DISK_HOME_RAW}$([ "${DISK_HOME_PCT:-0}" -ge "$DISK_ALERT_THRESHOLD" ] && echo ' ⚠️' || true)"

# --- Network ---
IP_ETH0=$(safe "ip -4 addr show eth0 | awk '/inet / {print \$2}' | cut -d/ -f1")
IP_WLAN0=$(safe "ip -4 addr show wlan0 | awk '/inet / {print \$2}' | paste -sd ', ' -")
LATENCY=$(safe "ping -c 3 1.1.1.1 | tail -1 | awk -F '/' '{print \$5 \" ms\"}'")
SYSTEM_DNS=$(safe "awk '/^nameserver/ {print \$2; exit}' /etc/resolv.conf")

# --- Docker ---
DOCKER_RUNNING=$(safe "docker ps --format '{{.Names}}' | wc -l")
DOCKER_LIST=$(safe "docker ps --format '• {{.Names}} — {{.Status}}'")

# --- Service health ---
PIHOLE_STATUS=$(safe "docker inspect -f '{{.State.Health.Status}}' pihole")
UNBOUND_STATUS=$(safe "docker inspect -f '{{.State.Health.Status}}' unbound")
NPM_STATUS=$(safe "docker inspect -f '{{.State.Health.Status}}' nginx-proxy-manager")
KUMA_STATUS=$(safe "docker inspect -f '{{.State.Health.Status}}' uptime-kuma")
NETALERTX_STATUS=$(safe "docker inspect -f '{{.State.Health.Status}}' NetAlertX")
CROWDSEC_STATUS=$(safe "docker inspect -f '{{.State.Health.Status}}' crowdsec")
TAILSCALE_STATUS=$(safe "docker inspect -f '{{.State.Health.Status}}' tailscale")

# --- Alerts section (shown at top if anything is wrong) ---
ALERTS_BLOCK=""
UNHEALTHY_NAMES=$(safe "docker ps --filter health=unhealthy --format '• {{.Names}}'")
if [ "$TEMP_INT" -ge "$TEMP_ALERT_THRESHOLD" ] || \
   [ "${DISK_ROOT_PCT:-0}" -ge "$DISK_ALERT_THRESHOLD" ] || \
   [ -n "$UNHEALTHY_NAMES" ]; then
  ALERTS_BLOCK="
🚨 ALERTS:"
  [ "$TEMP_INT" -ge "$TEMP_ALERT_THRESHOLD" ] && \
    ALERTS_BLOCK="$ALERTS_BLOCK
• Temperature: ${TEMP_RAW}°C"
  [ "${DISK_ROOT_PCT:-0}" -ge "$DISK_ALERT_THRESHOLD" ] && \
    ALERTS_BLOCK="$ALERTS_BLOCK
• Disk /: ${DISK_ROOT_PCT}%"
  [ -n "$UNHEALTHY_NAMES" ] && \
    ALERTS_BLOCK="$ALERTS_BLOCK
• Unhealthy containers:
$UNHEALTHY_NAMES"
fi

# --- DNS ---
DNS_PIHOLE=$(safe "dig +short google.com @127.0.0.1 | head -1")
DNS_UNBOUND=$(safe "dig +short google.com @127.0.0.1 -p 5335 | head -1")
LOCAL_DOMAIN=$(safe "[ -n \"$LOCAL_TEST_DOMAIN\" ] && dig +short \"$LOCAL_TEST_DOMAIN\" @127.0.0.1 | head -1 || echo 'not configured'")

# --- CrowdSec ---
CROWDSEC_ALERTS=$(safe "docker exec crowdsec cscli alerts list --limit 5 2>/dev/null | head -20")
CROWDSEC_DECISIONS=$(safe "docker exec crowdsec cscli decisions list 2>/dev/null | head -20")

# --- NetAlertX ---
NETALERT_DEVICES=$(safe "docker exec NetAlertX sqlite3 /data/db/app.db 'select count(*) from Devices;'")

# --- Backup ---
BACKUP_LAST=$(safe "find $HOMELAB_DIR/backups -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-")
BACKUP_SIZE=$(safe "[ -n \"$BACKUP_LAST\" ] && du -sh \"$BACKUP_LAST\" | awk '{print \$1}' || echo N/A")

REPORT="📊 RPi Homelab Report${ALERTS_BLOCK}

🖥 Host: rpi
⏱ Uptime: $UPTIME
🌡 Temp: $TEMP
⚙ Load: $LOAD
💾 RAM: $RAM
📀 Disk /: $DISK_ROOT
🏠 Disk home: $DISK_HOME

🌐 Network
eth0: $IP_ETH0
wlan0: $IP_WLAN0
Latency: $LATENCY
System DNS: $SYSTEM_DNS

🐳 Docker ($DOCKER_RUNNING running)
$DOCKER_LIST

🧩 Services
$(health_icon "$PIHOLE_STATUS") Pi-hole: $PIHOLE_STATUS
$(health_icon "$UNBOUND_STATUS") Unbound: $UNBOUND_STATUS
$(health_icon "$NPM_STATUS") NPM: $NPM_STATUS
$(health_icon "$KUMA_STATUS") Uptime Kuma: $KUMA_STATUS
$(health_icon "$NETALERTX_STATUS") NetAlertX: $NETALERTX_STATUS
$(health_icon "$CROWDSEC_STATUS") CrowdSec: $CROWDSEC_STATUS
$(health_icon "$TAILSCALE_STATUS") Tailscale: $TAILSCALE_STATUS

🔎 DNS
Pi-hole: $DNS_PIHOLE
Unbound: $DNS_UNBOUND
Local domain: $LOCAL_DOMAIN

🛡 CrowdSec
Alerts: $CROWDSEC_ALERTS
Decisions: $CROWDSEC_DECISIONS

📡 NetAlertX
Devices: $NETALERT_DEVICES

💾 Backup
Last: $BACKUP_LAST
Size: $BACKUP_SIZE"

echo "$REPORT"

if [[ -x "$TELEGRAM_SCRIPT" ]]; then
  "$TELEGRAM_SCRIPT" "$REPORT"
fi
