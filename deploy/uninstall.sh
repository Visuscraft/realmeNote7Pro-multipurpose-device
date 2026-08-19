#!/usr/bin/env bash
# Stops the device runtime and the updater, and removes the boot hook.
# Installed releases stay in $DEVICE_HOME unless --purge is given.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

rm -f "$HOME/.termux/boot/10-realme-device.sh"

if [ -f "${DEVICE_STATE_DIR}/updater.pid" ]; then
  kill "$(cat "${DEVICE_STATE_DIR}/updater.pid")" 2>/dev/null || true
  rm -f "${DEVICE_STATE_DIR}/updater.pid"
fi

bash "${DEVICE_SOURCE_DIR}/device/device.sh" stop || true

command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock || true

if [ "$PURGE" -eq 1 ]; then
  device::warn "removing $DEVICE_HOME"
  rm -rf "$DEVICE_HOME"
fi

echo "uninstalled"
