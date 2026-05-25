#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"

TELEGRAM_BOT_TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' "$HOMELAB_DIR/.env" | cut -d= -f2-)
TELEGRAM_CHAT_ID=$(grep -E '^TELEGRAM_CHAT_ID=' "$HOMELAB_DIR/.env" | cut -d= -f2-)

MESSAGE="$1"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="$MESSAGE"
