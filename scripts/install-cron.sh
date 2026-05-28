#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"

CRON_FILE="/tmp/homelab-cron"

mkdir -p "$HOMELAB_DIR/logs"
mkdir -p "$HOMELAB_DIR/backups"

crontab -l 2>/dev/null > "$CRON_FILE" || true

sed -i '/# homelab-start/,/# homelab-end/d' "$CRON_FILE"

cat >> "$CRON_FILE" <<EOF

# homelab-start

# Every 5 min — quick watchdog: sends Telegram if load/disk/temp/DNS/container bad
*/5 * * * * /bin/bash ${HOMELAB_DIR}/scripts/healthcheck.sh >> ${HOMELAB_DIR}/logs/healthcheck.log 2>&1

# Every 15 min — stateful alerts (fires once per event, sends recovery message)
*/15 * * * * /bin/bash ${HOMELAB_DIR}/scripts/monitor.sh >> ${HOMELAB_DIR}/logs/monitor.log 2>&1

# Daily OS package list refresh at 00:30
30 0 * * * /bin/bash ${HOMELAB_DIR}/scripts/os-update.sh >> ${HOMELAB_DIR}/logs/os-update.log 2>&1

# Daily Docker services update at 01:00
0 1 * * * /bin/bash ${HOMELAB_DIR}/scripts/update.sh >> ${HOMELAB_DIR}/logs/update_cron.log 2>&1

# Weekly version check (Monday 08:00) — sends Telegram if updates available
0 8 * * 1 /bin/bash ${HOMELAB_DIR}/scripts/check-updates.sh --notify >> ${HOMELAB_DIR}/logs/cron.log 2>&1

# Daily backup at 02:00
0 2 * * * /bin/bash ${HOMELAB_DIR}/scripts/backup.sh >> ${HOMELAB_DIR}/logs/backup.log 2>&1

# Daily RPi report at 09:00
0 9 * * * /bin/bash ${HOMELAB_DIR}/scripts/rpi-report.sh >> ${HOMELAB_DIR}/logs/cron.log 2>&1

# homelab-end
EOF

crontab "$CRON_FILE"
rm "$CRON_FILE"

echo "Cron installed:"
crontab -l

# --- Logrotate ---
LOGROTATE_CONF="/etc/logrotate.d/homelab"
if command -v logrotate &>/dev/null; then
  sudo tee "$LOGROTATE_CONF" > /dev/null <<LOGROTATE
${HOMELAB_DIR}/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
}
LOGROTATE
  echo "Logrotate installed: $LOGROTATE_CONF"
else
  echo "logrotate not found — skipping"
fi
