# shellcheck shell=bash
# shellcheck disable=SC2034  # SERVICES is used by scripts that source this file
SERVICES=(
  unbound
  pihole
  nginx
  uptime-kuma
  netalertx
  tailscale
  crowdsec
)
