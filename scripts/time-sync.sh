#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$HOMELAB_DIR/logs"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/time-sync.log"

NTP_SERVER="${NTP_SERVER:-pool.ntp.org}"
# Abort if NTP offset > 1 year — indicates broken time source or network issue
MAX_SAFE_OFFSET=31536000

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $*" | tee -a "$LOG_FILE"; }

if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

trap 'log "TIME SYNC FAILED"; "$SCRIPT_DIR/telegram.sh" "❌ time-sync FAILED on rpi — check $LOG_FILE" 2>/dev/null || true' ERR

log "========== TIME SYNC START =========="
log "System clock: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# --- Validate system clock before sync ---
CURRENT_YEAR=$(date +%Y)
if [ "$CURRENT_YEAR" -lt 2024 ]; then
  warn "System clock year ($CURRENT_YEAR) is clearly wrong — proceeding with forced sync"
fi

# --- Query NTP offset without applying (validation step) ---
if command -v ntpdate &>/dev/null; then
  log "Querying NTP offset (dry-run): $NTP_SERVER"
  # -q = query only, do not set; output: "offset X.XXXXXX sec"
  QUERY=$(ntpdate -q "$NTP_SERVER" 2>&1 | tee -a "$LOG_FILE" || true)
  OFFSET_RAW=$(echo "$QUERY" | grep -oP 'offset [-\d.]+' | awk '{print $2}' | head -1 || echo "")

  if [ -n "$OFFSET_RAW" ]; then
    # Strip sign for comparison (bash only handles integers)
    OFFSET_ABS=$(echo "$OFFSET_RAW" | awk '{printf "%d", ($1 < 0 ? -$1 : $1)}')
    log "NTP offset: ${OFFSET_RAW}s"

    if [ "$OFFSET_ABS" -gt "$MAX_SAFE_OFFSET" ]; then
      log "ABORT: NTP offset (${OFFSET_ABS}s) exceeds limit (${MAX_SAFE_OFFSET}s) — time source may be invalid"
      "$SCRIPT_DIR/telegram.sh" "❌ time-sync ABORTED — NTP offset ${OFFSET_ABS}s exceeds safety limit" 2>/dev/null || true
      exit 1
    fi

    if [ "$OFFSET_ABS" -gt 3600 ]; then
      warn "Large offset (${OFFSET_RAW}s > 1h) — clock is significantly off"
    fi

    log "Offset within safety limits — proceeding"
  else
    warn "Could not parse NTP offset — proceeding without pre-validation"
  fi

  # Apply sync
  log "Syncing via ntpdate"
  ntpdate -u "$NTP_SERVER" >> "$LOG_FILE" 2>&1

elif command -v chronyc &>/dev/null; then
  log "Querying offset via chronyc"
  chronyc tracking | tee -a "$LOG_FILE"
  log "Forcing immediate step sync"
  chronyc makestep >> "$LOG_FILE" 2>&1

else
  log "ntpdate/chronyc not found — syncing via systemd-timesyncd"
  systemctl restart systemd-timesyncd
  # Wait up to 15s for sync
  for i in $(seq 1 5); do
    sleep 3
    if timedatectl show --property=NTPSynchronized --value 2>/dev/null | grep -q "yes"; then
      log "Synchronized after $((i * 3))s"
      break
    fi
  done
fi

# --- Post-sync validation ---
NEW_YEAR=$(date +%Y)
log "Clock after sync: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

if [ "$NEW_YEAR" -lt 2024 ]; then
  log "ERROR: Year after sync ($NEW_YEAR) still invalid — sync may have failed"
  "$SCRIPT_DIR/telegram.sh" "❌ time-sync: clock still wrong after sync (year $NEW_YEAR)" 2>/dev/null || true
  exit 1
fi

log "timedatectl status:"
timedatectl | tee -a "$LOG_FILE"

log "========== TIME SYNC DONE ==========="
log ""
