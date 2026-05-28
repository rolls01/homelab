#!/usr/bin/env bash
set -euo pipefail

# Sends Telegram alerts when thresholds are crossed, and recovery messages when resolved.
# Stateful via /tmp/homelab-monitor/ — no alert spam; each event fires once.
# Run every 15 minutes via cron.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DISK_THRESHOLD="${DISK_THRESHOLD:-80}"
TEMP_THRESHOLD="${TEMP_THRESHOLD:-70}"

STATE_DIR="/tmp/homelab-monitor"
mkdir -p "$STATE_DIR"

send() {
  "$SCRIPT_DIR/telegram.sh" "$1" 2>/dev/null || true
}

# alert KEY IS_BAD MSG_BAD MSG_OK
# Fires MSG_BAD on bad→good transition, MSG_OK on good→bad transition. Idempotent.
alert() {
  local key="$1" is_bad="$2" msg_bad="$3" msg_ok="$4"
  local state="$STATE_DIR/$key"
  if [ "$is_bad" = "1" ]; then
    [ ! -f "$state" ] && { send "$msg_bad"; touch "$state"; }
  else
    [ -f "$state" ] && { rm -f "$state"; send "$msg_ok"; }
  fi
}

# --- Disk usage ---
while read -r pct mount; do
  key="disk_${mount//\//__}"
  alert "$key" \
    "$([ "${pct:-0}" -ge "$DISK_THRESHOLD" ] && echo 1 || echo 0)" \
    "⚠️ Homelab — disk $mount: ${pct}% (threshold ${DISK_THRESHOLD}%)" \
    "✅ Homelab — disk $mount: OK (${pct}%)"
done < <(df / | awk 'NR>1 {gsub(/%/,""); print $5, $6}')

# --- CPU temperature (RPi only) ---
if command -v vcgencmd &>/dev/null; then
  TEMP=$(vcgencmd measure_temp 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' || echo "0")
  TEMP_INT="${TEMP%.*}"
  alert "temp" \
    "$([ "${TEMP_INT:-0}" -ge "$TEMP_THRESHOLD" ] && echo 1 || echo 0)" \
    "🌡 Homelab — temperature: ${TEMP}°C (threshold ${TEMP_THRESHOLD}°C)" \
    "✅ Homelab — temperature: OK (${TEMP}°C)"
fi

# --- Unhealthy containers ---
UNHEALTHY=$(docker ps --filter health=unhealthy --format "{{.Names}}" 2>/dev/null || true)

if [ -n "$UNHEALTHY" ]; then
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    alert "container_${name}" "1" \
      "🔴 Homelab — container unhealthy: $name" \
      "✅ Homelab — $name: healthy"
  done <<< "$UNHEALTHY"
fi

# Recovery: clear state for containers that are no longer unhealthy
for state_file in "$STATE_DIR"/container_*; do
  [ -f "$state_file" ] || continue
  name="${state_file##*container_}"
  if ! grep -qx "$name" <<< "${UNHEALTHY:-}"; then
    rm -f "$state_file"
    send "✅ Homelab — $name: healthy"
  fi
done

# --- Reboot required (kernel/package update) ---
alert "reboot_required" \
  "$([ -f /var/run/reboot-required ] && echo 1 || echo 0)" \
  "🔄 Homelab — reboot required (kernel update). Run: sudo reboot" \
  "✅ Homelab — reboot done, clock running"
