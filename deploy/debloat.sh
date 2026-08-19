#!/usr/bin/env bash
# Removes bloatware and disables background services so the OS stops eating
# CPU, RAM and battery on a device that runs unattended.
#
#   deploy/debloat.sh              show what would change (dry run, default)
#   deploy/debloat.sh --apply      apply the changes
#   deploy/debloat.sh --restore    undo everything this script changed
#   deploy/debloat.sh --list       print the packages/services it manages
#
# Nothing is uninstalled: packages are disabled for the current user, which is
# reversible with --restore and survives neither a factory reset nor an OTA.
#
# Backends (auto-detected, override with DEVICE_DEBLOAT_BACKEND):
#   root    run through "su -c"        (rooted device)
#   adb     run through "adb shell"    (wireless debugging, no root needed)
#   direct  run commands directly      (already running as the shell user)

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../device" && pwd)/lib/common.sh"

BLOATWARE_LIST="${DEVICE_BLOATWARE_LIST:-$DEVICE_SOURCE_DIR/stock/bloatware.txt}"
SERVICES_LIST="${DEVICE_SERVICES_LIST:-$DEVICE_SOURCE_DIR/stock/services.txt}"

DISABLED_FILE="${DEVICE_STATE_DIR}/debloat-packages.txt"
SETTINGS_BACKUP="${DEVICE_STATE_DIR}/debloat-settings.bak"
STANDBY_BACKUP="${DEVICE_STATE_DIR}/debloat-standby.bak"

ACTION="apply"
WANT_DRY_RUN=""
for arg in "$@"; do
  case "$arg" in
    --apply)   ACTION="apply";   WANT_DRY_RUN="${WANT_DRY_RUN:-0}" ;;
    --restore) ACTION="restore"; WANT_DRY_RUN="${WANT_DRY_RUN:-0}" ;;
    --list)    ACTION="list" ;;
    --dry-run) WANT_DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) device::die "usage: debloat.sh [--apply|--restore|--list|--dry-run]" ;;
  esac
done

# Without an explicit action the script only reports what it would change.
DRY_RUN="${WANT_DRY_RUN:-1}"

# ---------------------------------------------------------------------------
# Backend
# ---------------------------------------------------------------------------

debloat::detect_backend() {
  if [ -n "${DEVICE_DEBLOAT_BACKEND:-}" ]; then
    printf '%s\n' "$DEVICE_DEBLOAT_BACKEND"
    return 0
  fi
  if command -v su >/dev/null 2>&1 && su -c 'id -u' >/dev/null 2>&1; then
    printf 'root\n'
  elif command -v adb >/dev/null 2>&1 &&
    adb shell 'echo ok' 2>/dev/null | grep -q ok; then
    printf 'adb\n'
  elif command -v pm >/dev/null 2>&1 || [ -x /system/bin/pm ]; then
    printf 'direct\n'
  else
    printf 'none\n'
  fi
}

BACKEND="$(debloat::detect_backend)"

# debloat::sh <command string>
# Runs an Android shell command through the selected backend. Output is
# returned on stdout, the exit status is that of the remote command.
debloat::sh() {
  local cmd="$1"
  case "$BACKEND" in
    root)   su -c "$cmd" ;;
    adb)    adb shell "$cmd" ;;
    direct) PATH="/system/bin:$PATH" sh -c "$cmd" ;;
    *)      return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Input validation - list entries end up in a shell command string
# ---------------------------------------------------------------------------

debloat::valid_package() {
  case "$1" in
    *[!A-Za-z0-9._]*|'') return 1 ;;
    *) return 0 ;;
  esac
}

debloat::valid_token() {
  case "$1" in
    *[!A-Za-z0-9._-]*|'') return 1 ;;
    *) return 0 ;;
  esac
}

# Reads a list file, dropping comments, inline comments and blank lines.
debloat::read_list() {
  local file="$1" line
  [ -f "$file" ] || device::die "list not found: $file"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$line" ] && printf '%s\n' "$line"
  done < "$file"
}

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------

debloat::package_installed() {
  local pkg="$1"
  debloat::sh "pm list packages '$pkg'" 2>/dev/null |
    tr -d '\r' | grep -qx "package:$pkg"
}

debloat::disable_packages() {
  local pkg installed=0 disabled=0 skipped=0
  while IFS= read -r pkg; do
    if ! debloat::valid_package "$pkg"; then
      device::warn "ignoring invalid package name: $pkg"
      continue
    fi
    if ! debloat::package_installed "$pkg"; then
      skipped=$((skipped + 1))
      continue
    fi
    installed=$((installed + 1))

    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'would disable package %s\n' "$pkg"
      continue
    fi

    if debloat::sh "pm disable-user --user 0 '$pkg'" >/dev/null 2>&1; then
      device::info "disabled package $pkg"
      grep -qxF "$pkg" "$DISABLED_FILE" 2>/dev/null ||
        printf '%s\n' "$pkg" >> "$DISABLED_FILE"
      disabled=$((disabled + 1))
    else
      device::warn "could not disable $pkg (protected by the system?)"
    fi
  done < <(debloat::read_list "$BLOATWARE_LIST")

  if [ "$DRY_RUN" -eq 1 ]; then
    device::info "$installed package(s) present would be disabled, $skipped not installed"
  else
    device::info "disabled $disabled package(s), $skipped not installed"
  fi
}

debloat::restore_packages() {
  local pkg restored=0
  [ -f "$DISABLED_FILE" ] || return 0
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    debloat::valid_package "$pkg" || continue
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'would enable package %s\n' "$pkg"
      continue
    fi
    if debloat::sh "pm enable '$pkg'" >/dev/null 2>&1; then
      device::info "enabled package $pkg"
      restored=$((restored + 1))
    else
      device::warn "could not enable $pkg"
    fi
  done < "$DISABLED_FILE"
  [ "$DRY_RUN" -eq 1 ] || rm -f "$DISABLED_FILE"
  device::info "re-enabled $restored package(s)"
}

# ---------------------------------------------------------------------------
# Services / settings
# ---------------------------------------------------------------------------

debloat::backup_setting() {
  local namespace="$1" key="$2" current
  # Only the first value seen is kept, so repeated runs stay reversible.
  if grep -q "^${namespace} ${key} " "$SETTINGS_BACKUP" 2>/dev/null; then
    return 0
  fi
  current="$(debloat::sh "settings get $namespace $key" 2>/dev/null |
    tr -d '\r' | head -n 1)"
  printf '%s %s %s\n' "$namespace" "$key" "${current:-null}" >> "$SETTINGS_BACKUP"
}

debloat::apply_setting() {
  local namespace="$1" key="$2" value="$3"

  case "$namespace" in
    global|system|secure) ;;
    *) device::warn "ignoring unknown settings namespace: $namespace"; return 0 ;;
  esac
  if ! debloat::valid_token "$key"; then
    device::warn "ignoring invalid settings key: $key"
    return 0
  fi
  # An empty value ("") clears the setting.
  if [ "$value" != '""' ] && ! debloat::valid_token "$value"; then
    device::warn "ignoring invalid value for $namespace/$key: $value"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would set %s/%s to %s (currently %s)\n' "$namespace" "$key" "$value" \
      "$(debloat::sh "settings get $namespace $key" 2>/dev/null |
        tr -d '\r' | head -n 1)"
    return 0
  fi

  debloat::backup_setting "$namespace" "$key"
  if [ "$value" = '""' ]; then
    debloat::sh "settings delete $namespace $key" >/dev/null 2>&1 ||
      device::warn "could not clear $namespace/$key"
  elif debloat::sh "settings put $namespace $key '$value'" >/dev/null 2>&1; then
    device::info "set $namespace/$key to $value"
  else
    device::warn "could not set $namespace/$key"
  fi
}

debloat::apply_standby() {
  local pkg="$1" current

  if ! debloat::valid_package "$pkg"; then
    device::warn "ignoring invalid package name: $pkg"
    return 0
  fi
  debloat::package_installed "$pkg" || return 0

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would restrict background activity of %s\n' "$pkg"
    return 0
  fi

  if ! grep -q "^${pkg} " "$STANDBY_BACKUP" 2>/dev/null; then
    current="$(debloat::sh "am get-standby-bucket '$pkg'" 2>/dev/null |
      tr -d '\r' | head -n 1)"
    printf '%s %s\n' "$pkg" "${current:-10}" >> "$STANDBY_BACKUP"
  fi

  if debloat::sh "am set-standby-bucket '$pkg' restricted" >/dev/null 2>&1; then
    device::info "restricted background activity of $pkg"
  else
    device::warn "could not restrict $pkg"
  fi
}

debloat::apply_services() {
  local line directive a b c
  while IFS= read -r line; do
    # shellcheck disable=SC2086
    set -- $line
    directive="${1:-}"
    a="${2:-}"; b="${3:-}"; c="${4:-}"
    case "$directive" in
      setting) debloat::apply_setting "$a" "$b" "$c" ;;
      standby) debloat::apply_standby "$a" ;;
      *) device::warn "ignoring unknown directive: $directive" ;;
    esac
  done < <(debloat::read_list "$SERVICES_LIST")
}

debloat::restore_services() {
  local namespace key value pkg bucket

  if [ -f "$SETTINGS_BACKUP" ]; then
    while read -r namespace key value; do
      [ -n "${key:-}" ] || continue
      debloat::valid_token "$key" || continue
      case "$namespace" in global|system|secure) ;; *) continue ;; esac
      if [ "$value" != "null" ] && [ -n "$value" ] &&
        ! debloat::valid_token "$value"; then
        device::warn "not restoring $namespace/$key: unsafe value"
        continue
      fi
      if [ "$DRY_RUN" -eq 1 ]; then
        printf 'would restore %s/%s to %s\n' "$namespace" "$key" "$value"
        continue
      fi
      if [ "$value" = "null" ] || [ -z "$value" ]; then
        debloat::sh "settings delete $namespace $key" >/dev/null 2>&1 || true
      else
        debloat::sh "settings put $namespace $key '$value'" >/dev/null 2>&1 ||
          device::warn "could not restore $namespace/$key"
      fi
      device::info "restored $namespace/$key"
    done < "$SETTINGS_BACKUP"
    [ "$DRY_RUN" -eq 1 ] || rm -f "$SETTINGS_BACKUP"
  fi

  if [ -f "$STANDBY_BACKUP" ]; then
    while read -r pkg bucket; do
      [ -n "${pkg:-}" ] || continue
      debloat::valid_package "$pkg" || continue
      debloat::valid_token "$bucket" || continue
      if [ "$DRY_RUN" -eq 1 ]; then
        printf 'would restore standby bucket of %s to %s\n' "$pkg" "$bucket"
        continue
      fi
      debloat::sh "am set-standby-bucket '$pkg' '$bucket'" >/dev/null 2>&1 ||
        device::warn "could not restore the standby bucket of $pkg"
    done < "$STANDBY_BACKUP"
    [ "$DRY_RUN" -eq 1 ] || rm -f "$STANDBY_BACKUP"
  fi
}

# ---------------------------------------------------------------------------

debloat::list() {
  printf '# packages (%s)\n' "$BLOATWARE_LIST"
  debloat::read_list "$BLOATWARE_LIST"
  printf '\n# services (%s)\n' "$SERVICES_LIST"
  debloat::read_list "$SERVICES_LIST"
}

main() {
  if [ "$ACTION" = "list" ]; then
    debloat::list
    return 0
  fi

  device::init_dirs

  if [ "$BACKEND" = "none" ]; then
    device::error "no way to talk to the Android package manager."
    device::error "root the device, or enable wireless debugging and run:"
    device::error "  pkg install android-tools && adb pair <host:port> && adb connect <host:port>"
    return 1
  fi
  device::info "using the $BACKEND backend"

  if [ "$DRY_RUN" -eq 1 ]; then
    device::info "dry run - nothing is changed, re-run with --apply"
  fi

  case "$ACTION" in
    apply)
      debloat::disable_packages
      debloat::apply_services
      [ "$DRY_RUN" -eq 1 ] ||
        device::info "debloat finished, reboot to reclaim the memory"
      ;;
    restore)
      debloat::restore_services
      debloat::restore_packages
      [ "$DRY_RUN" -eq 1 ] || device::info "restore finished"
      ;;
  esac
}

main
