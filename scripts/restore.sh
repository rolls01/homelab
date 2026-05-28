#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_ROOT="$HOMELAB_DIR/backups"
DATA_DIR="$HOMELAB_DIR/data"

if [[ ! -f "$HOMELAB_DIR/.env" ]]; then
  echo "ERROR: Missing $HOMELAB_DIR/.env"
  echo ""
  echo "Create it first:"
  echo "  cp $HOMELAB_DIR/.env.example $HOMELAB_DIR/.env"
  echo ""
  echo "Then fill required secrets and run restore again."
  exit 1
fi

if [[ ! -d "$BACKUP_ROOT" ]]; then
  echo "Backup directory not found: $BACKUP_ROOT"
  exit 1
fi

echo "Available backups:"
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort

echo ""
read -rp "Enter backup directory name to restore: " BACKUP_NAME

BACKUP_DIR="$BACKUP_ROOT/$BACKUP_NAME"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Backup not found: $BACKUP_DIR"
  exit 1
fi

echo "Verifying backup integrity..."
if [[ -f "$BACKUP_DIR/checksums.sha256" ]]; then
  (cd "$BACKUP_DIR" && sha256sum -c checksums.sha256 --quiet) || {
    echo "ERROR: Checksum verification failed — backup may be corrupt"
    exit 1
  }
  echo "  Checksums OK"
else
  echo "  No checksums.sha256 found — skipping checksum check"
fi

shopt -s nullglob
CHECK_ARCHIVES=("$BACKUP_DIR"/*.tar.gz)
for archive in "${CHECK_ARCHIVES[@]}"; do
  if ! sudo tar -tzf "$archive" >/dev/null 2>&1; then
    echo "ERROR: Corrupt archive: $(basename "$archive")"
    exit 1
  fi
done
echo "  Archives OK"

echo "Stopping services..."
"$SCRIPT_DIR/stop-all.sh" || true

echo "Creating Docker network if missing..."
docker network create homelab 2>/dev/null || true

echo "Creating data directory..."
mkdir -p "$DATA_DIR"

echo "Restoring archives from: $BACKUP_DIR"

ARCHIVES=("$BACKUP_DIR"/*.tar.gz)

if (( ${#ARCHIVES[@]} == 0 )); then
  echo "No .tar.gz archives found in: $BACKUP_DIR"
  exit 1
fi

for archive in "${ARCHIVES[@]}"; do
  echo "Restoring: $(basename "$archive")"

  case "$(basename "$archive")" in
    pihole.tar.gz)
      mkdir -p "$DATA_DIR/pihole"
      sudo tar -xzf "$archive" -C "$DATA_DIR/pihole"
      ;;

    nginx.tar.gz|nginx-letsencrypt.tar.gz|uptime-kuma.tar.gz|netalertx.tar.gz|tailscale.tar.gz|unbound.tar.gz)
      mkdir -p "$DATA_DIR"
      sudo tar -xzf "$archive" -C "$DATA_DIR"
      ;;

    crowdsec-data.tar.gz|crowdsec-config.tar.gz)
      mkdir -p "$DATA_DIR/crowdsec"
      sudo tar -xzf "$archive" -C "$DATA_DIR/crowdsec"
      ;;

    *)
      echo "Skipping unknown archive: $(basename "$archive")"
      ;;
  esac
done

echo ""
echo "Starting services..."
"$SCRIPT_DIR/start-all.sh"

echo ""
echo "Restore completed."
