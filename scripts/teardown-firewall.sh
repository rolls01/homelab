#!/usr/bin/env bash
set -euo pipefail

RULES_SCRIPT="/usr/local/bin/homelab-docker-rules.sh"
SERVICE_FILE="/etc/systemd/system/homelab-docker-rules.service"

echo "=== Homelab firewall teardown ==="
echo ""

# --- Stop and remove systemd service ---

if systemctl is-active --quiet homelab-docker-rules 2>/dev/null; then
  echo "Stopping homelab-docker-rules service..."
  systemctl stop homelab-docker-rules
fi

if systemctl is-enabled --quiet homelab-docker-rules 2>/dev/null; then
  echo "Disabling homelab-docker-rules service..."
  systemctl disable homelab-docker-rules
fi

if [ -f "$SERVICE_FILE" ]; then
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  echo "Removed $SERVICE_FILE"
fi

if [ -f "$RULES_SCRIPT" ]; then
  rm -f "$RULES_SCRIPT"
  echo "Removed $RULES_SCRIPT"
fi

# --- Flush DOCKER-USER rules (leave Docker's own rules intact) ---

if iptables -L DOCKER-USER &>/dev/null 2>&1; then
  echo "Flushing DOCKER-USER chain..."
  iptables -F DOCKER-USER
fi

if iptables-legacy -L DOCKER-USER &>/dev/null 2>&1; then
  iptables-legacy -F DOCKER-USER
fi

# --- Disable UFW ---

if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  echo "Disabling UFW..."
  ufw disable
fi

# --- Clear stale legacy iptables rules (from previous broken runs) ---

echo "Flushing iptables-legacy rules..."
iptables-legacy -F 2>/dev/null || true
iptables-legacy -X 2>/dev/null || true
iptables-legacy -t nat -F 2>/dev/null || true
iptables-legacy -t nat -X 2>/dev/null || true
iptables-legacy -t mangle -F 2>/dev/null || true
iptables-legacy -t mangle -X 2>/dev/null || true

# --- Restart Docker to restore its iptables rules cleanly ---

echo "Restarting Docker to restore iptables rules..."
systemctl restart docker

echo ""
echo "Firewall teardown complete. UFW disabled, all custom rules removed."
