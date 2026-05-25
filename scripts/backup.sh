#!/usr/bin/env bash
set -euo pipefail

DATE=$(date +%Y-%m-%d_%H-%M)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"

BACKUP_ROOT="$HOMELAB_DIR/backups"
BACKUP_DIR="$BACKUP_ROOT/$DATE"

LOG_FILE="$BACKUP_ROOT/backup.log"

RETENTION_DAYS=14

if ! sudo -n true 2>/dev/null; then
  echo "ERROR: sudo requires a password — backup cannot run unattended."
  echo "Fix: sudo visudo and add:"
  echo "  $(whoami) ALL=(ALL) NOPASSWD: /usr/bin/tar"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

backup_folder() {
  NAME=$1
  SOURCE=$2
  shift 2

  log "Backing up $NAME"

  set +e
  sudo tar \
    --warning=no-file-changed \
    -czf "$BACKUP_DIR/$NAME.tar.gz" \
    "$@" \
    -C "$(dirname "$SOURCE")" \
    "$(basename "$SOURCE")"

  TAR_EXIT=$?
  set -e

  if [[ "$TAR_EXIT" -gt 1 ]]; then
    log "$NAME failed with tar exit code $TAR_EXIT"
    exit "$TAR_EXIT"
  fi

  if [[ "$TAR_EXIT" -eq 1 ]]; then
    log "$NAME completed with warnings"
  fi

  SIZE=$(du -sh "$BACKUP_DIR/$NAME.tar.gz" | awk '{print $1}')
  log "$NAME completed ($SIZE)"
}

log "========== BACKUP START =========="

backup_folder "pihole" "$HOMELAB_DIR/data/pihole/etc-pihole"
backup_folder "nginx" "$HOMELAB_DIR/data/nginx" "--exclude=*/logs/*"
backup_folder "nginx-letsencrypt" "$HOMELAB_DIR/data/nginx-letsencrypt"
backup_folder "uptime-kuma" "$HOMELAB_DIR/data/uptime-kuma"
backup_folder "netalertx" "$HOMELAB_DIR/data/netalertx"
backup_folder "tailscale" "$HOMELAB_DIR/data/tailscale"
backup_folder "unbound" "$HOMELAB_DIR/data/unbound"
backup_folder "crowdsec-data" "$HOMELAB_DIR/data/crowdsec/data"
backup_folder "crowdsec-config" "$HOMELAB_DIR/data/crowdsec/config"

log "Verifying archives"
for archive in "$BACKUP_DIR"/*.tar.gz; do
  if ! sudo tar -tzf "$archive" >/dev/null 2>&1; then
    log "CORRUPT: $(basename "$archive")"
    "$HOMELAB_DIR/scripts/telegram.sh" "❌ Backup CORRUPT: $(basename "$archive") on rpi" || true
    exit 1
  fi
done
log "All archives OK"

log "Generating checksums"
(cd "$BACKUP_DIR" && sha256sum ./*.tar.gz > checksums.sha256)

log "Cleaning old backups older than $RETENTION_DAYS days"

find "$BACKUP_ROOT" \
  -maxdepth 1 \
  -type d \
  -mtime +$RETENTION_DAYS \
  -exec rm -rf {} \;

TOTAL=$(du -sh "$BACKUP_DIR" | awk '{print $1}')

log "Backup saved in: $BACKUP_DIR"
log "Total backup size: $TOTAL"
log "=========== BACKUP END ==========="

echo ""
echo "Backup completed:"
echo "$BACKUP_DIR"

"$HOMELAB_DIR/scripts/telegram.sh" "✅ Backup completed on rpi
📦 Size: $TOTAL
📁 Path: $BACKUP_DIR"

# Optional: offsite sync via rclone (configure rclone first)
if command -v rclone &>/dev/null && rclone listremotes 2>/dev/null | grep -q .; then
  log "Syncing to offsite (rclone)"
  rclone sync "$BACKUP_DIR" "offsite:homelab-backups/$DATE" >> "$LOG_FILE" 2>&1 \
    && log "Offsite sync completed" \
    || log "Offsite sync FAILED (check rclone config)"
fi
