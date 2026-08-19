# stock/

Stock (factory default) baseline of the device.

| File | Purpose |
| --- | --- |
| `config.env` | Default configuration values loaded by every script. Device specific overrides live in `$DEVICE_HOME/config.env`. |
| `packages.txt` | Termux packages installed non-interactively by `deploy/install.sh`. |
| `bloatware.txt` | Android packages `deploy/debloat.sh` disables (never uninstalls). |
| `services.txt` | Settings and background restrictions `deploy/debloat.sh` applies to cut CPU, RAM and battery usage. |

Nothing in this directory is modified at runtime, which makes it safe to reset a
device to its stock behaviour by deleting `$DEVICE_HOME/config.env`.

Both debloat lists are plain text with `#` comments, so a device can use its own
selection by pointing `DEVICE_BLOATWARE_LIST` / `DEVICE_SERVICES_LIST` at copies
of them in `~/.realme-device/config.env`.
