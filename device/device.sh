#!/usr/bin/env bash
# Runtime entry point of the multipurpose device.
#
#   device/device.sh start [mode]   start (or switch to) a mode in background
#   device/device.sh stop           stop the running mode
#   device/device.sh restart [mode] restart the running (or given) mode
#   device/device.sh status         print the current status as JSON
#   device/device.sh run [mode]     run a mode in the foreground

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DEVICE_PID_FILE="${DEVICE_STATE_DIR}/device.pid"
DEVICE_MODE_FILE="${DEVICE_STATE_DIR}/mode"

device::current_mode() {
  if [ -f "$DEVICE_MODE_FILE" ]; then
    cat "$DEVICE_MODE_FILE"
  else
    printf '%s\n' "$DEVICE_MODE"
  fi
}

device::mode_script() {
  local mode="$1"
  local script="$DEVICE_SOURCE_DIR/modes/${mode}.sh"
  [ -f "$script" ] || device::die "unknown mode: $mode"
  printf '%s\n' "$script"
}

device::running_pid() {
  [ -f "$DEVICE_PID_FILE" ] || return 1
  local pid
  pid="$(cat "$DEVICE_PID_FILE")"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  printf '%s\n' "$pid"
}

device::stop() {
  local pid
  if ! pid="$(device::running_pid)"; then
    device::info "device is not running"
    rm -f "$DEVICE_PID_FILE"
    return 0
  fi
  device::info "stopping device (pid $pid)"
  kill "$pid" 2>/dev/null || true
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 10 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  kill -9 "$pid" 2>/dev/null || true
  rm -f "$DEVICE_PID_FILE"
}

device::start() {
  local mode="$1"
  local script
  script="$(device::mode_script "$mode")"
  device::stop
  device::init_dirs
  printf '%s\n' "$mode" > "$DEVICE_MODE_FILE"
  device::info "starting mode '$mode'"
  DEVICE_ACTIVE_MODE="$mode" nohup bash "$script" \
    >> "$DEVICE_LOG_DIR/${mode}.log" 2>&1 &
  printf '%s\n' "$!" > "$DEVICE_PID_FILE"
  device::info "mode '$mode' running with pid $(cat "$DEVICE_PID_FILE")"
  bash "$DEVICE_SOURCE_DIR/device/status.sh" >/dev/null
}

device::run_foreground() {
  local mode="$1"
  local script
  script="$(device::mode_script "$mode")"
  device::init_dirs
  printf '%s\n' "$mode" > "$DEVICE_MODE_FILE"
  device::info "running mode '$mode' in foreground"
  DEVICE_ACTIVE_MODE="$mode" exec bash "$script"
}

main() {
  local command="${1:-status}"
  shift || true
  case "$command" in
    start)
      device::start "${1:-$(device::current_mode)}"
      ;;
    run)
      device::run_foreground "${1:-$(device::current_mode)}"
      ;;
    stop)
      device::stop
      ;;
    restart)
      device::start "${1:-$(device::current_mode)}"
      ;;
    status)
      bash "$DEVICE_SOURCE_DIR/device/status.sh"
      ;;
    *)
      device::die "usage: device.sh {start|run|stop|restart|status} [mode]"
      ;;
  esac
}

main "$@"
