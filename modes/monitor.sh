#!/usr/bin/env bash
# monitor mode - records battery, storage and connectivity samples so the
# dashboard can show a history of the device.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

device::init_dirs
SAMPLE_FILE="${DEVICE_STATE_DIR}/samples.csv"
SAMPLE_INTERVAL="${DEVICE_MONITOR_INTERVAL:-60}"

if [ ! -f "$SAMPLE_FILE" ]; then
  printf 'timestamp,battery_percentage,free_bytes,online\n' > "$SAMPLE_FILE"
fi

device::info "monitor mode started (interval ${SAMPLE_INTERVAL}s)"

trap 'device::info "monitor mode stopped"; exit 0' TERM INT

while true; do
  bash "$DEVICE_SOURCE_DIR/device/status.sh" >/dev/null || true

  battery="$(device::json_get "$DEVICE_STATUS_FILE" battery_percentage)"
  free_bytes="$(device::json_get "$DEVICE_STATUS_FILE" free_bytes)"
  if curl -fsS --max-time 10 -o /dev/null "https://api.github.com" 2>/dev/null; then
    online=1
  else
    online=0
  fi

  printf '%s,%s,%s,%s\n' "$(device::timestamp)" "${battery:-}" \
    "${free_bytes:-}" "$online" >> "$SAMPLE_FILE"

  sleep "$SAMPLE_INTERVAL" &
  wait $!
done
