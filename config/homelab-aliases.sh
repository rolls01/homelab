# Homelab diagnostic aliases
# Source from ~/.bashrc:  echo 'source ~/homelab/config/homelab-aliases.sh' >> ~/.bashrc

# ===== HOMELAB HEALTH =====

alias htoppi='btop'

alias hload='uptime'

alias hram='free -h'

alias hswap='free -m | awk '\''/Swap:/ {printf "Swap: %d/%dMB (%.0f%%)\n", $3, $2, $3/$2*100}'\'''

alias hdisk='df -h / /home 2>/dev/null || df -h /'

alias hdns='dig google.com @127.0.0.1 +short'

alias hdns5='dig google.com @127.0.0.1 -p 5335 +short'

alias hiowait='iostat -xm 1'

alias hdocker='docker stats --no-stream'

alias hlogs='sudo find /var/lib/docker/containers/ -name "*-json.log" -exec du -h {} + 2>/dev/null | sort -hr | head -20'

alias hspace='docker system df'

alias hio='sudo iotop -oPa'

# ===== RASPBERRY PI HARDWARE =====

alias htemp='vcgencmd measure_temp'

alias hfreq='vcgencmd measure_clock arm | awk -F= '\''{printf "CPU: %.0f MHz\n", $2/1000000}'\'''

alias hvolt='vcgencmd measure_volts core'

# Decodes the throttle hex bitmask into human-readable flags
hthrottle() {
  local raw flags=()
  raw=$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2) || { echo "vcgencmd not available"; return 1; }
  local val=$(( raw ))
  echo "Raw: $raw"
  (( val & 0x00001 )) && flags+=("⚡ Under-voltage detected")
  (( val & 0x00002 )) && flags+=("🔥 Arm frequency capped")
  (( val & 0x00004 )) && flags+=("🌡 Currently throttled")
  (( val & 0x00008 )) && flags+=("🌡 Soft temperature limit active")
  (( val & 0x10000 )) && flags+=("⚡ Under-voltage has occurred")
  (( val & 0x20000 )) && flags+=("🔥 Arm frequency capping has occurred")
  (( val & 0x40000 )) && flags+=("🌡 Throttling has occurred")
  (( val & 0x80000 )) && flags+=("🌡 Soft temperature limit has occurred")
  if [ ${#flags[@]} -eq 0 ]; then
    echo "✅ No throttling — all clear"
  else
    printf '%s\n' "${flags[@]}"
  fi
}

# ===== COMBINED OVERVIEW =====

hhealth() {
  echo "===== LOAD =====" && uptime
  echo
  echo "===== RAM =====" && free -h
  echo
  echo "===== DISK =====" && df -h / /home 2>/dev/null || df -h /
  echo
  echo "===== TEMP / THROTTLE =====" && htemp && hthrottle
  echo
  echo "===== DOCKER =====" && docker stats --no-stream
  echo
  echo "===== DNS =====" && dig google.com @127.0.0.1 +short
}

export -f hthrottle hhealth
