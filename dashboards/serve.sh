#!/usr/bin/env bash
# Serves the local dashboard.
#
# The dashboard is a static page; the status data is exposed as status.json
# next to it. The server binds to 127.0.0.1 by default, set
# DEVICE_DASHBOARD_BIND=0.0.0.0 to expose it on the local network.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

device::require python3
device::init_dirs

WEB_ROOT="${DEVICE_HOME}/www"
BIND="${DEVICE_DASHBOARD_BIND:-127.0.0.1}"
PORT="${DEVICE_DASHBOARD_PORT}"

mkdir -p "$WEB_ROOT"
cp "$DEVICE_SOURCE_DIR"/dashboards/*.html "$WEB_ROOT/"
cp "$DEVICE_SOURCE_DIR"/dashboards/*.js "$WEB_ROOT/" 2>/dev/null || true

bash "$DEVICE_SOURCE_DIR/device/status.sh" >/dev/null || true
ln -sf "$DEVICE_STATUS_FILE" "$WEB_ROOT/status.json"

refresh_loop() {
  while true; do
    bash "$DEVICE_SOURCE_DIR/device/status.sh" >/dev/null || true
    sleep 30
  done
}

refresh_loop &
REFRESH_PID=$!

cleanup() {
  kill "$REFRESH_PID" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

device::info "dashboard listening on http://${BIND}:${PORT}/"
cd "$WEB_ROOT"
exec python3 -m http.server "$PORT" --bind "$BIND"
