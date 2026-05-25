#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$HOMELAB_DIR/logs"

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/os-update.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

trap 'log "OS UPDATE FAILED"; "$SCRIPT_DIR/telegram.sh" "❌ OS update FAILED on rpi — check $LOG_FILE" 2>/dev/null || true' ERR

log "========== OS UPDATE START =========="

log "Refreshing apt package list"
sudo apt update -y >> "$LOG_FILE" 2>&1

UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable' || true)
log "Packages upgradable: $UPGRADABLE"

log "=========== OS UPDATE END ==========="

"$SCRIPT_DIR/telegram.sh" "✅ OS package list refreshed — ${UPGRADABLE} package(s) upgradable"
