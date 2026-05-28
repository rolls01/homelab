#!/usr/bin/env bash
set -euo pipefail

# Quick watchdog — collects metrics, sends one Telegram message if any threshold
# is exceeded. Stateless: fires on every bad run. Run via cron every 5 minutes.
#
# Thresholds (override via env):
#   DISK_THRESHOLD  — disk usage % (default: 85)
#   LOAD_THRESHOLD  — 1-min load average (default: 3)
#   TEMP_THRESHOLD  — CPU temp in °C (default: 75)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"

DISK_THRESHOLD="${DISK_THRESHOLD:-85}"
LOAD_THRESHOLD="${LOAD_THRESHOLD:-3}"
TEMP_THRESHOLD="${TEMP_THRESHOLD:-75}"

send() { "$SCRIPT_DIR/telegram.sh" "$1" 2>/dev/null || true; }

# ===== METRICS =====

LOAD=$(awk '{print $1}' /proc/loadavg)
LOAD_INT=$(echo "$LOAD" | awk '{printf "%d", $1}')

MEM=$(free -m | awk '/Mem:/ {printf "%d/%dMB (%.0f%%)", $3, $2, $3/$2*100}')

SWAP=$(free -m | awk '/Swap:/ {
  if ($2 == 0) print "disabled"
  else printf "%d/%dMB (%.0f%%)", $3, $2, $3/$2*100
}')

DISK_PCT=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
DISK_HUMAN=$(df -h / | awk 'NR==2 {print $3"/"$2" ("$5")"}')

TEMP_RAW=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 || echo "N/A")
TEMP_INT=0
[[ "$TEMP_RAW" =~ ^([0-9]+) ]] && TEMP_INT="${BASH_REMATCH[1]}"

if timeout 5 dig google.com @127.0.0.1 +short >/dev/null 2>&1; then
  DNS="✅ OK"
else
  DNS="❌ FAIL"
fi

UNHEALTHY=$(docker ps --filter health=unhealthy --format "• {{.Names}}" 2>/dev/null || true)

# ===== THRESHOLD CHECKS =====

ISSUES=()

[ "$LOAD_INT" -ge "$LOAD_THRESHOLD" ] && \
  ISSUES+=("⚙ Load: ${LOAD} (próg ${LOAD_THRESHOLD})")

[ "${DISK_PCT:-0}" -ge "$DISK_THRESHOLD" ] && \
  ISSUES+=("📀 Disk: ${DISK_HUMAN} (próg ${DISK_THRESHOLD}%)")

[ "$TEMP_INT" -ge "$TEMP_THRESHOLD" ] && \
  ISSUES+=("🌡 Temp: ${TEMP_RAW} (próg ${TEMP_THRESHOLD}°C)")

[ "$DNS" = "❌ FAIL" ] && \
  ISSUES+=("🔎 DNS: FAIL")

[ -n "$UNHEALTHY" ] && \
  ISSUES+=("🔴 Unhealthy containers:"$'\n'"$UNHEALTHY")

# ===== SILENT WHEN OK =====

[ ${#ISSUES[@]} -eq 0 ] && exit 0

# ===== SEND ALERT =====

ISSUES_TEXT=$(printf '%s\n' "${ISSUES[@]}")

send "⚠️ Homelab — problem wykryty

${ISSUES_TEXT}

📊 Stan systemu:
Load: $LOAD
RAM: $MEM
Swap: $SWAP
Disk: $DISK_HUMAN
Temp: $TEMP_RAW
DNS: $DNS"
