#!/usr/bin/env bash
# server mode - serves the local dashboard over HTTP on DEVICE_DASHBOARD_PORT
# and keeps the status file up to date while it runs.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

exec bash "$DEVICE_SOURCE_DIR/dashboards/serve.sh"
