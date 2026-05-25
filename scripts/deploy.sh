#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"

cd "$HOMELAB_DIR"

echo "Checking .env..."
if [[ ! -f "$HOMELAB_DIR/.env" ]]; then
  echo "ERROR: Missing $HOMELAB_DIR/.env"
  exit 1
fi

echo "Pulling latest changes..."
git pull --ff-only

echo "Updating services..."
"$SCRIPT_DIR/update.sh"

echo ""
echo "Docker status:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "Deploy completed."
