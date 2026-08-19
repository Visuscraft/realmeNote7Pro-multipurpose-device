#!/usr/bin/env bash
# idle mode - keeps the device alive and refreshes the status file.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

device::info "idle mode started"

trap 'device::info "idle mode stopped"; exit 0' TERM INT

while true; do
  bash "$DEVICE_SOURCE_DIR/device/status.sh" >/dev/null || true
  sleep 60 &
  wait $!
done
