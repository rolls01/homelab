#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   check-updates.sh           -- interactive: review and apply updates
#   check-updates.sh --notify  -- send Telegram if updates found (for cron)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$HOMELAB_DIR/versions.env"

NOTIFY_ONLY=false
[[ "${1:-}" == "--notify" ]] && NOTIFY_ONLY=true

# --- Helpers ---

current_version() {
  grep -E "^${1}=" "$VERSIONS_FILE" 2>/dev/null | cut -d= -f2- || echo "?"
}

set_version() {
  sed -i "s|^${1}=.*|${1}=${2}|" "$VERSIONS_FILE"
}

dockerhub_latest() {
  local image=$1 strip_v=${2:-false}
  local result tag

  result=$(curl -sf --max-time 15 \
    "https://hub.docker.com/v2/repositories/${image}/tags?page_size=25&ordering=last_updated" \
    || echo "")
  [[ -z "$result" ]] && echo "unknown" && return

  if command -v jq &>/dev/null; then
    tag=$(echo "$result" | jq -r '.results[].name' \
      | grep -vE '^(latest|beta|rc|alpha|dev|test|edge|nightly|arm|amd64|arm64|sha256|linux|stable|release|main|master)' \
      | grep -E '^v?[0-9]' | head -1 || echo "")
  else
    tag=$(echo "$result" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' \
      | grep -vE '^(latest|beta|rc|alpha|dev|test|edge|nightly|arm|amd64|arm64|sha256|linux|stable|release|main|master)' \
      | grep -E '^v?[0-9]' | head -1 || echo "")
  fi

  [[ -z "$tag" ]] && echo "unknown" && return
  [[ "$strip_v" == "true" ]] && echo "${tag#v}" || echo "$tag"
}

# --- Service definitions ---
# Format: "KEY|dockerhub_image|strip_v|display_name"

DEFS=(
  "PIHOLE_VERSION|pihole/pihole|false|Pi-hole"
  "NPM_VERSION|jc21/nginx-proxy-manager|false|Nginx Proxy Manager"
  "TAILSCALE_VERSION|tailscale/tailscale|false|Tailscale"
  "UPTIME_KUMA_VERSION|louislam/uptime-kuma|false|Uptime Kuma"
  "NETALERTX_VERSION|jokobsk/netalertx|false|NetAlertX"
  "CROWDSEC_VERSION|crowdsecurity/crowdsec|false|CrowdSec"
  "UNBOUND_VERSION|mvance/unbound-rpi|false|Unbound"
)

# --- Check Docker images ---

docker_updates=()

printf "\n%-24s %-20s %-20s\n" "Service" "Current" "Latest"
printf '%s\n' "----------------------------------------------------------------"

for def in "${DEFS[@]}"; do
  IFS='|' read -r key image strip_v desc <<< "$def"
  current=$(current_version "$key")
  latest=$(dockerhub_latest "$image" "$strip_v")

  if [[ "$latest" == "unknown" ]]; then
    printf "%-24s %-20s %-20s\n" "$desc" "$current" "⚠ check failed"
  elif [[ "$current" == "$latest" ]]; then
    printf "%-24s %-20s %-20s\n" "$desc" "$current" "✓"
  else
    printf "%-24s %-20s %s ⬆\n" "$desc" "$current" "$latest"
    docker_updates+=("$key|$current|$latest|$desc")
  fi
done

# --- Check system packages ---

echo ""
printf "%-24s " "System packages"
apt_upgradable=$(apt list --upgradable 2>/dev/null | grep "/" || true)
apt_count=$(echo "$apt_upgradable" | grep -c "/" 2>/dev/null || echo 0)

if [[ "$apt_count" -gt 0 ]]; then
  printf "%s\n" "$apt_count package(s) upgradable ⬆"
else
  printf "%s\n" "✓"
fi

# --- Notify mode (for cron) ---

if $NOTIFY_ONLY; then
  if [[ ${#docker_updates[@]} -eq 0 && "$apt_count" -eq 0 ]]; then
    exit 0
  fi

  msg="📦 Homelab updates available"$'\n'

  if [[ ${#docker_updates[@]} -gt 0 ]]; then
    msg+=$'\n'"🐳 Docker:"$'\n'
    for u in "${docker_updates[@]}"; do
      IFS='|' read -r _ cur new desc <<< "$u"
      msg+="• $desc: $cur → $new"$'\n'
    done
  fi

  if [[ "$apt_count" -gt 0 ]]; then
    msg+=$'\n'"📦 System: $apt_count package(s) upgradable"$'\n'
  fi

  msg+=$'\n'"Run ./scripts/check-updates.sh to apply."
  "$SCRIPT_DIR/telegram.sh" "$msg"
  exit 0
fi

# --- Interactive apply ---

if [[ ${#docker_updates[@]} -eq 0 && "$apt_count" -eq 0 ]]; then
  echo ""
  echo "Everything up to date."
  exit 0
fi

echo ""

if [[ ${#docker_updates[@]} -gt 0 ]]; then
  echo "Docker image updates:"
  for u in "${docker_updates[@]}"; do
    IFS='|' read -r key cur new desc <<< "$u"
    read -rp "  $desc: $cur → $new  Apply? [y/N] " confirm
    if [[ "${confirm,,}" == "y" ]]; then
      set_version "$key" "$new"
      echo "    ✓ versions.env updated"
    fi
  done
fi

if [[ "$apt_count" -gt 0 ]]; then
  echo ""
  echo "System packages upgradable ($apt_count):"
  echo "$apt_upgradable" | head -10 | sed 's/^/  /'
  [[ "$apt_count" -gt 10 ]] && echo "  ... and $((apt_count - 10)) more"
  echo ""
  read -rp "Apply system updates now? [y/N] " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    sudo apt upgrade -y
    echo "  ✓ System updated"
  fi
fi

echo ""
echo "Done. Run update.sh to pull new Docker images."
