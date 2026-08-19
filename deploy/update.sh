#!/usr/bin/env bash
# Fully automatic, no-user-interaction updater.
#
#   deploy/update.sh            check once and update when a new release exists
#   deploy/update.sh --force    reinstall the published release unconditionally
#   deploy/update.sh --watch    keep checking every DEVICE_UPDATE_INTERVAL seconds
#
# The script never prompts: it downloads the manifest, verifies the SHA-256 of
# the release archive, installs it next to the previous ones and atomically
# flips the "current" symlink before restarting the runtime.

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

FORCE=0
WATCH=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --watch) WATCH=1 ;;
    --once) WATCH=0 ;;
    *) device::die "usage: update.sh [--force] [--watch]" ;;
  esac
done

device::require curl
device::require tar

LOCK_DIR="${DEVICE_HOME}/state/update.lock"

update::acquire_lock() {
  device::init_dirs
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    device::warn "another update is already running, skipping"
    return 1
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
  return 0
}

update::release_lock() {
  trap - EXIT
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

# Release identifiers become directory names, so keep them boring.
update::sanitize_version() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

update::restart_runtime() {
  local runtime="${DEVICE_CURRENT_LINK}/device/device.sh"
  if [ -x "$runtime" ] || [ -f "$runtime" ]; then
    bash "$runtime" restart >/dev/null 2>&1 ||
      device::warn "could not restart the device runtime"
  fi
}

update::prune() {
  local keep="${DEVICE_KEEP_RELEASES}"
  local current_target
  current_target="$(readlink "$DEVICE_CURRENT_LINK" 2>/dev/null || true)"
  local release
  # Newest first, skip the ones we keep, never delete the active release.
  while IFS= read -r release; do
    [ -n "$release" ] || continue
    [ "$release" != "$current_target" ] || continue
    device::info "removing old release $(basename "$release")"
    rm -rf "$release"
  done < <(find "$DEVICE_RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d |
    sort | head -n "-${keep}")
}

update::install() {
  local manifest="$1" version="$2" url="$3" expected_sha="$4"
  local workdir target
  workdir="$(mktemp -d "${DEVICE_HOME}/state/download.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$workdir'; rm -f '$manifest'" EXIT

  device::info "downloading $version"
  curl -fsSL --retry 3 --retry-delay 5 --max-time 600 \
    -o "$workdir/release.tar.gz" "$url" ||
    device::die "download failed: $url"

  if [ -n "$expected_sha" ]; then
    local actual_sha
    actual_sha="$(device::sha256 "$workdir/release.tar.gz")"
    if [ "${actual_sha,,}" != "${expected_sha,,}" ]; then
      device::die "checksum mismatch (expected $expected_sha, got $actual_sha)"
    fi
    device::info "checksum verified"
  else
    device::warn "manifest has no sha256, installing without verification"
  fi

  mkdir -p "$workdir/payload"
  tar -xzf "$workdir/release.tar.gz" -C "$workdir/payload"
  [ -f "$workdir/payload/device/device.sh" ] ||
    device::die "release archive does not contain device/device.sh"

  target="${DEVICE_RELEASES_DIR}/${version}"
  rm -rf "$target"
  mv "$workdir/payload" "$target"
  chmod +x "$target"/device/*.sh "$target"/modes/*.sh \
    "$target"/deploy/*.sh "$target"/dashboards/*.sh 2>/dev/null || true

  # Atomically point "current" at the new release.
  ln -sfn "$target" "${DEVICE_CURRENT_LINK}.new"
  mv -Tf "${DEVICE_CURRENT_LINK}.new" "$DEVICE_CURRENT_LINK"
  printf '%s\n' "$version" > "$DEVICE_VERSION_FILE"
  cp "$manifest" "${DEVICE_STATE_DIR}/latest.json"

  rm -rf "$workdir"

  device::info "installed $version"
  update::prune
  update::restart_runtime

  if [ "$WATCH" -eq 1 ]; then
    # Ask the watch loop to continue with the freshly installed updater.
    printf '%s\n' "$version" > "${DEVICE_STATE_DIR}/updater.restart"
  fi
}

update::check_once() {
  local manifest version url sha installed
  manifest="$(mktemp "${DEVICE_STATE_DIR}/manifest.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f '$manifest'" EXIT

  if ! curl -fsSL --retry 3 --retry-delay 5 --max-time 60 \
    -o "$manifest" "$DEVICE_MANIFEST_URL"; then
    device::warn "manifest unreachable: $DEVICE_MANIFEST_URL"
    rm -f "$manifest"
    return 1
  fi

  version="$(update::sanitize_version "$(device::json_get "$manifest" version)")"
  url="$(device::json_get "$manifest" url)"
  sha="$(device::json_get "$manifest" sha256)"

  if [ -z "$version" ] || [ -z "$url" ]; then
    device::warn "manifest is incomplete, ignoring it"
    rm -f "$manifest"
    return 1
  fi

  case "$url" in
    https://*) ;;
    *) device::die "refusing to download from a non https url: $url" ;;
  esac

  installed="$(device::installed_version)"
  if [ "$FORCE" -eq 0 ] && [ "$installed" = "$version" ] &&
    [ -d "$DEVICE_CURRENT_LINK" ]; then
    device::info "already up to date ($installed)"
    rm -f "$manifest"
    return 0
  fi

  device::info "updating $installed -> $version"
  update::install "$manifest" "$version" "$url" "$sha"
  rm -f "$manifest"
}

update::run_check() {
  update::acquire_lock || return 0
  # A failing check (network, checksum, disk) must never stop the watch loop.
  ( update::check_once ) || device::warn "update check failed"
  update::release_lock
}

main() {
  if [ "$WATCH" -eq 0 ]; then
    update::run_check
    return 0
  fi

  device::info "watching for updates every ${DEVICE_UPDATE_INTERVAL}s"
  rm -f "${DEVICE_STATE_DIR}/updater.restart"
  while true; do
    update::run_check
    FORCE=0
    if [ -f "${DEVICE_STATE_DIR}/updater.restart" ]; then
      rm -f "${DEVICE_STATE_DIR}/updater.restart"
      device::info "restarting the updater from $(device::installed_version)"
      exec bash "${DEVICE_CURRENT_LINK}/deploy/update.sh" --watch
    fi
    sleep "$DEVICE_UPDATE_INTERVAL"
  done
}

main
