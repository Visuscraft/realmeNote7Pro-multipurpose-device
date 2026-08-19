#!/usr/bin/env bash
# Shared helpers for every script of the multipurpose device.
#
# Usage:  . "$(dirname "$0")/../device/lib/common.sh"

set -euo pipefail

# Absolute path of the checkout/release this file belongs to.
DEVICE_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DEVICE_SOURCE_DIR

# Load the stock defaults first, then the device specific overrides.
# shellcheck source=../../stock/config.env
. "$DEVICE_SOURCE_DIR/stock/config.env"

if [ -f "${DEVICE_HOME}/config.env" ]; then
  # shellcheck disable=SC1091
  . "${DEVICE_HOME}/config.env"
fi

DEVICE_LOG_DIR="${DEVICE_HOME}/logs"
DEVICE_STATE_DIR="${DEVICE_HOME}/state"
DEVICE_RELEASES_DIR="${DEVICE_HOME}/releases"
DEVICE_CURRENT_LINK="${DEVICE_HOME}/current"
DEVICE_VERSION_FILE="${DEVICE_STATE_DIR}/version"
DEVICE_STATUS_FILE="${DEVICE_STATE_DIR}/status.json"
export DEVICE_LOG_DIR DEVICE_STATE_DIR DEVICE_RELEASES_DIR \
  DEVICE_CURRENT_LINK DEVICE_VERSION_FILE DEVICE_STATUS_FILE

device::init_dirs() {
  mkdir -p "$DEVICE_LOG_DIR" "$DEVICE_STATE_DIR" "$DEVICE_RELEASES_DIR"
}

device::timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

device::log() {
  local level="$1"
  shift
  local line
  line="$(device::timestamp) [$level] $*"
  printf '%s\n' "$line"
  if mkdir -p "$DEVICE_LOG_DIR" 2>/dev/null; then
    printf '%s\n' "$line" >> "$DEVICE_LOG_DIR/device.log"
  fi
}

device::info()  { device::log INFO "$@"; }
device::warn()  { device::log WARN "$@" >&2; }
device::error() { device::log ERROR "$@" >&2; }

device::die() {
  device::error "$@"
  exit 1
}

device::require() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 ||
    device::die "required command not found: $cmd"
}

# device::json_get <file> <key>
# Reads a top level value from a JSON document. Uses jq when available and
# falls back to python3 so that a partially installed device can still update.
device::json_get() {
  local file="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" 'if has($k) then (.[$k]|tostring) else "" end' "$file"
  elif command -v python3 >/dev/null 2>&1; then
    DEVICE_JSON_KEY="$key" python3 - "$file" <<'PY'
import json
import os
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
value = data.get(os.environ["DEVICE_JSON_KEY"], "")
print("" if value is None else value)
PY
  else
    device::die "neither jq nor python3 is available to parse JSON"
  fi
}

device::installed_version() {
  if [ -f "$DEVICE_VERSION_FILE" ]; then
    cat "$DEVICE_VERSION_FILE"
  else
    printf 'none\n'
  fi
}

# device::sha256 <file>
device::sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  else
    device::die "no sha256 implementation available"
  fi
}
