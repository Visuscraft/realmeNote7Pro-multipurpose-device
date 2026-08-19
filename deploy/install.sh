#!/usr/bin/env bash
# One-shot, non-interactive installer for Termux.
#
#   pkg install -y git
#   git clone https://github.com/Visuscraft/realmeNote7Pro-multipurpose-device
#   bash realmeNote7Pro-multipurpose-device/deploy/install.sh
#
# After this script finished the device updates itself automatically: the
# updater runs in the background and Termux:Boot restarts everything after a
# reboot. No further user interaction is required.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

device::init_dirs

install::packages() {
  local list="$DEVICE_SOURCE_DIR/stock/packages.txt"
  if ! command -v pkg >/dev/null 2>&1; then
    device::warn "'pkg' not found, skipping package installation"
    return 0
  fi
  local packages=()
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && packages+=("$line")
  done < "$list"
  device::info "installing packages: ${packages[*]}"
  yes | pkg install -y "${packages[@]}" >/dev/null 2>&1 ||
    device::warn "some packages could not be installed"
}

install::config() {
  if [ ! -f "${DEVICE_HOME}/config.env" ]; then
    device::info "creating ${DEVICE_HOME}/config.env"
    {
      printf '# Device specific overrides of stock/config.env\n'
      printf '#DEVICE_MODE=monitor\n'
      printf '#DEVICE_UPDATE_INTERVAL=300\n'
      printf '#DEVICE_DASHBOARD_PORT=8080\n'
    } > "${DEVICE_HOME}/config.env"
  fi
}

# Seed releases/bootstrap from this checkout so the device is usable even
# before the first release has been downloaded.
install::bootstrap() {
  local target="${DEVICE_RELEASES_DIR}/bootstrap"
  if [ "$DEVICE_SOURCE_DIR" -ef "$target" ]; then
    return 0
  fi
  device::info "seeding bootstrap release from $DEVICE_SOURCE_DIR"
  rm -rf "$target"
  mkdir -p "$target"
  tar -C "$DEVICE_SOURCE_DIR" -cf - \
    device modes stock dashboards deploy README.md LICENSE |
    tar -C "$target" -xf -
  ln -sfn "$target" "${DEVICE_CURRENT_LINK}.new"
  mv -Tf "${DEVICE_CURRENT_LINK}.new" "$DEVICE_CURRENT_LINK"
  printf 'bootstrap\n' > "$DEVICE_VERSION_FILE"
}

install::boot_hook() {
  local boot_dir="$HOME/.termux/boot"
  mkdir -p "$boot_dir"
  cat > "$boot_dir/10-realme-device.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# Installed by realmeNote7Pro-multipurpose-device (deploy/install.sh).
exec bash "${DEVICE_CURRENT_LINK}/deploy/boot.sh"
EOF
  chmod +x "$boot_dir/10-realme-device.sh"
  device::info "Termux:Boot hook installed at $boot_dir/10-realme-device.sh"
}

main() {
  install::packages
  install::config
  install::bootstrap
  install::boot_hook

  device::info "fetching the published release"
  bash "${DEVICE_CURRENT_LINK}/deploy/update.sh" --force || true

  device::info "starting the runtime"
  bash "${DEVICE_CURRENT_LINK}/deploy/boot.sh"

  device::info "installation finished, version $(device::installed_version)"
  device::info "install Termux:Boot from F-Droid so updates survive a reboot"
}

main "$@"
