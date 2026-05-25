#!/usr/bin/env bash
set -euo pipefail

# Homelab OS provisioning for Raspberry Pi OS (Debian Bookworm, headless)
# Run once on a fresh install, from inside the cloned repo.
# Usage: sudo ./provision.sh
#
# Environment overrides:
#   HOMELAB_USER  — user that will run Docker (default: current logged-in user)
#   HOSTNAME_SET  — desired hostname (default: rpi)
#   TIMEZONE      — timezone (default: Europe/Warsaw)
#   SWAP_SIZE     — swap file size (default: 1G)

HOMELAB_USER="${HOMELAB_USER:-$(logname 2>/dev/null || echo "${SUDO_USER:-pi}")}"
HOSTNAME_SET="${HOSTNAME_SET:-rpi}"
TIMEZONE="${TIMEZONE:-Europe/Warsaw}"
SWAP_SIZE="${SWAP_SIZE:-1G}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn()  { echo "[$(date '+%H:%M:%S')] ⚠ $*"; }
ok()    { echo "[$(date '+%H:%M:%S')] ✓ $*"; }

if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

info "=== Homelab provisioning ==="
info "User: $HOMELAB_USER | Hostname: $HOSTNAME_SET | TZ: $TIMEZONE"
echo ""

# --- Hostname ---
info "Setting hostname to $HOSTNAME_SET"
hostnamectl set-hostname "$HOSTNAME_SET"
if grep -q "^127\.0\.1\.1" /etc/hosts; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $HOSTNAME_SET/" /etc/hosts
else
  echo "127.0.1.1 $HOSTNAME_SET" >> /etc/hosts
fi
ok "Hostname: $HOSTNAME_SET"

# --- Timezone ---
info "Setting timezone to $TIMEZONE"
timedatectl set-timezone "$TIMEZONE"
ok "Timezone: $TIMEZONE"

# --- Packages ---
info "Installing packages"
apt-get update -y
apt-get install -y --no-install-recommends \
  git \
  curl \
  ca-certificates \
  gnupg \
  lsb-release \
  dnsutils \
  vim \
  htop \
  logrotate \
  fail2ban
ok "Packages installed"

# --- Docker ---
if command -v docker &>/dev/null; then
  ok "Docker already installed ($(docker --version))"
else
  info "Installing Docker"
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  ok "Docker installed"
fi
usermod -aG docker "$HOMELAB_USER" 2>/dev/null && ok "User $HOMELAB_USER added to docker group" || true

# --- Docker daemon config ---
info "Writing /etc/docker/daemon.json"
mkdir -p /etc/docker
cp "$SCRIPT_DIR/config/docker-daemon.json" /etc/docker/daemon.json
systemctl restart docker
ok "Docker daemon configured"

# --- Swap ---
if swapon --show | grep -q .; then
  ok "Swap already configured"
else
  info "Creating ${SWAP_SIZE} swap"
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  # Low swappiness — use swap only under real memory pressure
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-homelab.conf
  sysctl -p /etc/sysctl.d/99-homelab.conf
  ok "Swap created (${SWAP_SIZE}, swappiness=10)"
fi

# --- Fail2ban ---
info "Enabling fail2ban"
systemctl enable --now fail2ban
ok "Fail2ban enabled"

# --- SSH hardening ---
warn "SSH hardening: requires SSH key in ~/.ssh/authorized_keys before applying!"
warn "Current session stays open. Reconnect will require key auth."
SSH_CONF="/etc/ssh/sshd_config.d/99-homelab.conf"
cat > "$SSH_CONF" << 'SSH_EOF'
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
X11Forwarding no
SSH_EOF
systemctl reload sshd
ok "SSH hardened ($SSH_CONF)"

# --- GPU memory (headless RPi) ---
for BOOT_CONFIG in /boot/firmware/config.txt /boot/config.txt; do
  if [ -f "$BOOT_CONFIG" ]; then
    if ! grep -q "^gpu_mem=" "$BOOT_CONFIG"; then
      echo "gpu_mem=16" >> "$BOOT_CONFIG"
      ok "gpu_mem=16 set in $BOOT_CONFIG"
    else
      ok "gpu_mem already set in $BOOT_CONFIG"
    fi
    break
  fi
done

echo ""
info "=== Provisioning complete ==="
echo ""
echo "Next steps:"
echo "  1. Log out and back in (docker group membership)"
echo "  2. cp .env.example .env && nano .env   (fill in secrets)"
echo "  3. bash scripts/restore.sh             (restore from backup)"
echo "     OR: bash scripts/start-all.sh       (fresh install)"
echo "  4. bash scripts/install-cron.sh        (set up cron + logrotate)"
echo ""
warn "SSH key required from now on — verify you can connect before closing session"
