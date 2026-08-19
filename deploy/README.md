# deploy/

Everything needed to turn a Termux installation into a self-updating device.

| Script | Purpose |
| --- | --- |
| `install.sh` | Non-interactive installer: packages, config, bootstrap release, Termux:Boot hook, first update, runtime start. |
| `update.sh` | Reads `latest.json`, verifies the SHA-256 of `release.tar.gz`, installs it atomically and restarts the runtime. `--watch` keeps polling, `--force` reinstalls. |
| `boot.sh` | Started by Termux:Boot: takes a wake lock, starts the updater in watch mode and starts the configured mode. |
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
