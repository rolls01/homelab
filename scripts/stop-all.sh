#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$HOMELAB_DIR/compose"

source "$SCRIPT_DIR/services.sh"

for (( i=${#SERVICES[@]}-1; i>=0; i-- )); do
  dir="${SERVICES[$i]}"
  echo "Stopping $dir..."
  docker compose -f "$COMPOSE_DIR/$dir/docker-compose.yml" down
done
