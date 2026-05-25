#!/usr/bin/env bash
set -euo pipefail

# Trusted LAN subnets allowed to access admin interfaces
LAN_SUBNETS=(
  "192.168.0.0/24"
  "192.168.1.0/24"
)

# Admin ports exposed only to LAN (Docker bypasses UFW — handled via DOCKER-USER below)
ADMIN_PORTS=(8080 8181 3001 20211)

# Public ports that must be reachable from internet (accepted explicitly in DOCKER-USER)
PUBLIC_PORTS=(80 443)

RULES_SCRIPT="/usr/local/bin/homelab-docker-rules.sh"
SERVICE_FILE="/etc/systemd/system/homelab-docker-rules.service"

echo "=== Homelab firewall setup ==="
echo ""

# --- Install UFW if missing ---

if ! command -v ufw &>/dev/null; then
  echo "Installing UFW..."
  apt-get install -y ufw
fi

# --- Consolidate iptables backend ---
# Docker uses iptables-nft; if UFW wrote rules to iptables-legacy (different backend),
# both rule sets apply to packets independently — legacy DROP rules block Docker traffic.
# Fix: flush legacy rules and ensure the system uses iptables-nft consistently.

echo "Consolidating iptables backend to nft..."
if command -v iptables-legacy &>/dev/null; then
  iptables-legacy -F 2>/dev/null || true
  iptables-legacy -X 2>/dev/null || true
  iptables-legacy -t nat -F 2>/dev/null || true
  iptables-legacy -t nat -X 2>/dev/null || true
  iptables-legacy -t mangle -F 2>/dev/null || true
  iptables-legacy -t mangle -X 2>/dev/null || true
fi
if command -v update-alternatives &>/dev/null && [ -f /usr/sbin/iptables-nft ]; then
  update-alternatives --set iptables /usr/sbin/iptables-nft
  update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
fi

# --- IP forwarding ---
# UFW's sysctl.conf disables IP forwarding by default — Docker and Tailscale need it enabled.

echo "Enabling IP forwarding..."
sed -i 's|net/ipv4/ip_forward=0|net/ipv4/ip_forward=1|g' /etc/ufw/sysctl.conf
sed -i 's|#net/ipv4/ip_forward=1|net/ipv4/ip_forward=1|g' /etc/ufw/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

# --- UFW ---

echo "Configuring UFW..."
ufw --force reset

ufw default deny incoming
ufw default allow outgoing
ufw default allow forward

# SSH — must be first to avoid lockout
ufw allow 22/tcp comment "SSH"

# Public services
ufw allow 80/tcp comment "HTTP (NPM)"
ufw allow 443/tcp comment "HTTPS (NPM)"

# Pi-hole DNS
ufw allow 53/tcp comment "DNS"
ufw allow 53/udp comment "DNS"

# Pi-hole DHCP
ufw allow 67/udp comment "DHCP"

# Unbound (localhost only — only Pi-hole on this host needs it)
ufw allow from 127.0.0.1 to any port 5335 comment "Unbound (localhost)"
ufw allow from 172.16.0.0/12 to any port 5335 comment "Unbound (Docker networks)"

# Tailscale
ufw allow in on tailscale0 comment "Tailscale"

# Admin interfaces — LAN only (defense-in-depth for non-Docker access)
for subnet in "${LAN_SUBNETS[@]}"; do
  for port in "${ADMIN_PORTS[@]}"; do
    ufw allow from "$subnet" to any port "$port" proto tcp comment "Admin LAN"
  done
done

ufw --force enable

echo "Restarting Docker to restore iptables rules after UFW reset..."
systemctl restart docker

echo "UFW configured."
echo ""

# --- DOCKER-USER chain via systemd service ---
# Docker rewrites iptables on start, bypassing UFW entirely.
# DOCKER-USER is the first chain in FORWARD — explicitly ACCEPT public ports here
# so UFW's forward chain never gets a chance to drop them.

echo "Installing DOCKER-USER rules service..."

cat > "$RULES_SCRIPT" <<SCRIPT_EOF
#!/usr/bin/env bash
set -euo pipefail

LAN_SUBNETS=(${LAN_SUBNETS[*]@Q})
ADMIN_PORTS=(${ADMIN_PORTS[*]})
PUBLIC_PORTS=(${PUBLIC_PORTS[*]})

# Wait for Docker to create the DOCKER-USER chain (up to 15s)
for i in {1..15}; do
  iptables -L DOCKER-USER &>/dev/null && break
  sleep 1
done

if ! iptables -L DOCKER-USER &>/dev/null; then
  echo "ERROR: DOCKER-USER chain not found after 15s — is Docker running?" >&2
  exit 1
fi

iptables -F DOCKER-USER

# Established connections and loopback
iptables -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A DOCKER-USER -i lo -j ACCEPT
iptables -A DOCKER-USER -i tailscale0 -j ACCEPT

# Docker internal traffic (container-to-container via bridge networks)
iptables -A DOCKER-USER -s 172.16.0.0/12 -j ACCEPT

# Public ports — accept from anywhere (must be explicit: RETURN would let UFW drop them)
for port in "\${PUBLIC_PORTS[@]}"; do
  iptables -A DOCKER-USER -p tcp --dport "\$port" -j ACCEPT
done

# Admin ports — LAN only
for subnet in "\${LAN_SUBNETS[@]}"; do
  for port in "\${ADMIN_PORTS[@]}"; do
    iptables -A DOCKER-USER -p tcp --dport "\$port" -s "\$subnet" -j ACCEPT
  done
done

# Drop admin ports from all other sources
for port in "\${ADMIN_PORTS[@]}"; do
  iptables -A DOCKER-USER -p tcp --dport "\$port" -j DROP
done

iptables -A DOCKER-USER -j RETURN
SCRIPT_EOF

chmod +x "$RULES_SCRIPT"

cat > "$SERVICE_FILE" <<'SERVICE_EOF'
[Unit]
Description=Homelab DOCKER-USER iptables rules
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/homelab-docker-rules.sh

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable homelab-docker-rules
systemctl restart homelab-docker-rules

echo "DOCKER-USER chain configured."
echo ""
echo "Firewall setup complete."
echo ""
echo "Summary:"
ufw status numbered
