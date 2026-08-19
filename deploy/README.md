# deploy/

Everything needed to turn a Termux installation into a self-updating device.

| Script | Purpose |
| --- | --- |
| `install.sh` | Non-interactive installer: packages, config, bootstrap release, Termux:Boot hook, first update, runtime start. |
| `update.sh` | Reads `latest.json`, verifies the SHA-256 of `release.tar.gz`, installs it atomically and restarts the runtime. `--watch` keeps polling, `--force` reinstalls. |
| `boot.sh` | Started by Termux:Boot: takes a wake lock, starts the updater in watch mode and starts the configured mode. |
| `debloat.sh` | Disables pre-installed bloatware and resource hungry background services. Dry run by default, `--apply` to change, `--restore` to undo. |
| `uninstall.sh` | Stops everything and removes the boot hook (`--purge` also deletes `$DEVICE_HOME`). |

## Layout on the device

```
$DEVICE_HOME (default ~/.realme-device)
├── config.env            device specific overrides
├── current -> releases/auto-42
├── releases/
│   ├── bootstrap/        copy of the checkout used for the installation
│   └── auto-42/          downloaded release
├── state/
│   ├── version           installed release
│   ├── debloat-*.bak     what debloat.sh changed, used by --restore
│   ├── mode              active mode
│   ├── status.json       rendered by the dashboard
│   └── latest.json       manifest of the installed release
├── logs/
└── www/                  dashboard document root
```

## Update flow

1. `update.sh --watch` fetches `latest.json` every `DEVICE_UPDATE_INTERVAL` seconds.
2. If `version` differs from `state/version`, `release.tar.gz` is downloaded over HTTPS.
3. The archive is rejected unless its SHA-256 matches the manifest.
4. It is unpacked to `releases/<version>` and `current` is flipped atomically.
5. The runtime is restarted and old releases beyond `DEVICE_KEEP_RELEASES` are pruned.
6. The updater re-executes itself from the new release.

A lock directory (`state/update.lock`) makes concurrent updates impossible, and
a failed download or checksum leaves the previous release untouched.

## Debloating

`debloat.sh` reads `stock/bloatware.txt` (packages) and `stock/services.txt`
(settings and background restrictions) and applies them through the first
backend it finds:

| Backend | Requirement |
| --- | --- |
| `root` | `su` is available. |
| `adb` | `pkg install android-tools`, then pair/connect to the device's own wireless debugging endpoint. No root needed. |
| `direct` | The script already runs as the shell user (`pm` in `PATH`). |

```sh
~/.realme-device/current/deploy/debloat.sh            # show what would change
~/.realme-device/current/deploy/debloat.sh --apply    # apply
~/.realme-device/current/deploy/debloat.sh --restore  # undo everything
~/.realme-device/current/deploy/debloat.sh --list     # print the managed lists
```

Packages are **disabled for the current user, never uninstalled**, so every
change is reversible: `--restore` re-enables the packages listed in
`state/debloat-packages.txt` and writes back the original values recorded in
`state/debloat-settings.bak` and `state/debloat-standby.bak`. A factory reset
or an OTA also brings everything back.

Entries that are not installed on the device are silently skipped, and system
critical packages (telephony, SystemUI, settings, launcher, package installer,
permission controller) are deliberately absent from the list. Reboot after
`--apply` to reclaim the memory the disabled services were holding.
