#!/usr/bin/env bash
# Collects the state of the device and writes it to $DEVICE_STATUS_FILE.
# The JSON document is also what the dashboard renders.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

device::init_dirs

status::sanitize() {
  # Keep the JSON valid no matter what the underlying tool reports.
  printf '%s' "${1:-}" | tr -d '\000-\037"\\' | cut -c1-200
}

status::battery() {
  local level=""
  if command -v termux-battery-status >/dev/null 2>&1; then
    level="$(termux-battery-status 2>/dev/null |
      sed -n 's/.*"percentage"[[:space:]]*:[[:space:]]*\([0-9]\{1,3\}\).*/\1/p' |
      head -n 1)"
  fi
  printf '%s' "${level:-null}"
}

status::uptime() {
  local seconds=""
  if [ -r /proc/uptime ]; then
    seconds="$(cut -d. -f1 < /proc/uptime)"
  fi
  printf '%s' "${seconds:-0}"
}

status::free_bytes() {
  local target="${DEVICE_HOME}" bytes=""
  [ -d "$target" ] || target="$HOME"
  bytes="$(df -k "$target" 2>/dev/null |
    awk 'NR==2 {printf "%.0f", $4 * 1024; exit}')" || bytes=""
  printf '%s' "${bytes:-0}"
}

status::running() {
  local pid_file="${DEVICE_STATE_DIR}/device.pid"
  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    printf 'true'
  else
    printf 'false'
  fi
}

mode="$DEVICE_MODE"
if [ -f "${DEVICE_STATE_DIR}/mode" ]; then
  mode="$(cat "${DEVICE_STATE_DIR}/mode")"
fi

tmp_file="$(mktemp "${DEVICE_STATUS_FILE}.XXXXXX")"
cat > "$tmp_file" <<EOF
{
  "device": "realme Note 7 Pro",
  "hostname": "$(status::sanitize "$(uname -n)")",
  "version": "$(status::sanitize "$(device::installed_version)")",
  "mode": "$(status::sanitize "$mode")",
  "running": $(status::running),
  "battery_percentage": $(status::battery),
  "uptime_seconds": $(status::uptime),
  "free_bytes": $(status::free_bytes),
  "updated_at": "$(device::timestamp)"
}
EOF

mv "$tmp_file" "$DEVICE_STATUS_FILE"
cat "$DEVICE_STATUS_FILE"
