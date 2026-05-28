#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$HOMELAB_DIR/compose"
LOG_DIR="$HOMELAB_DIR/logs"

# shellcheck source=scripts/services.sh
source "$SCRIPT_DIR/services.sh"

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/update.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

trap 'log "Update script error (unexpected)"; "$SCRIPT_DIR/telegram.sh" "❌ Docker update FAILED on rpi — check $LOG_FILE" 2>/dev/null || true' ERR

FAILED=()

log "========== DOCKER UPDATE START =========="

log "Pre-update backup"
if "$SCRIPT_DIR/backup.sh" >> "$LOG_FILE" 2>&1; then
  log "Backup OK"
else
  log "Backup FAILED — aborting update"
  "$SCRIPT_DIR/telegram.sh" "❌ Pre-update backup FAILED on rpi — update aborted" 2>/dev/null || true
  exit 1
fi

for service in "${SERVICES[@]}"; do
  COMPOSE_FILE="$COMPOSE_DIR/$service/docker-compose.yml"

  if [[ ! -f "$COMPOSE_FILE" ]]; then
    log "Skipping $service — compose file not found"
    continue
  fi

  log "Updating $service"

  if (
    set -e
    cd "$COMPOSE_DIR/$service"
    docker compose --env-file "$HOMELAB_DIR/.env" --env-file "$HOMELAB_DIR/versions.env" pull >> "$LOG_FILE" 2>&1
    docker compose --env-file "$HOMELAB_DIR/.env" --env-file "$HOMELAB_DIR/versions.env" up -d --remove-orphans >> "$LOG_FILE" 2>&1
  ); then
    log "$service OK"
  else
    log "$service FAILED"
    FAILED+=("$service")
  fi
done

log "Docker cleanup"
docker image prune -f >> "$LOG_FILE" 2>&1

log "=========== DOCKER UPDATE END ==========="

if [ ${#FAILED[@]} -eq 0 ]; then
  "$SCRIPT_DIR/telegram.sh" "✅ Docker services updated"
else
  FAILED_LIST=$(printf '• %s\n' "${FAILED[@]}")
  "$SCRIPT_DIR/telegram.sh" "⚠️ Docker update: ${#FAILED[@]} service(s) failed:
${FAILED_LIST}
Check $LOG_FILE"
fi
