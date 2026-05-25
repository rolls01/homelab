#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$HOMELAB_DIR/compose"

source "$SCRIPT_DIR/services.sh"

for dir in "${SERVICES[@]}"; do
  echo "Starting $dir..."
  docker compose \
    --env-file "$HOMELAB_DIR/.env" \
    --env-file "$HOMELAB_DIR/versions.env" \
    -f "$COMPOSE_DIR/$dir/docker-compose.yml" \
    up -d
done
