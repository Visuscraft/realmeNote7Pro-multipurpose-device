#!/usr/bin/env bash
# Started by Termux:Boot (and by deploy/install.sh) to bring the device back
# to life without any user interaction.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

device::init_dirs

# Keep the CPU awake so the updater and the active mode keep running while the
# screen is off.
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock || true

UPDATER_PID_FILE="${DEVICE_STATE_DIR}/updater.pid"

boot::updater_running() {
  [ -f "$UPDATER_PID_FILE" ] || return 1
  local pid
  pid="$(cat "$UPDATER_PID_FILE")"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

if boot::updater_running; then
  device::info "updater already running (pid $(cat "$UPDATER_PID_FILE"))"
else
  device::info "starting the updater in watch mode"
  nohup bash "${DEVICE_CURRENT_LINK}/deploy/update.sh" --watch \
    >> "$DEVICE_LOG_DIR/updater.log" 2>&1 &
  printf '%s\n' "$!" > "$UPDATER_PID_FILE"
fi

device::info "starting the device runtime"
bash "${DEVICE_CURRENT_LINK}/device/device.sh" start
