# stock/

Stock (factory default) baseline of the device.

| File | Purpose |
| --- | --- |
| `config.env` | Default configuration values loaded by every script. Device specific overrides live in `$DEVICE_HOME/config.env`. |
| `packages.txt` | Termux packages installed non-interactively by `deploy/install.sh`. |

Nothing in this directory is modified at runtime, which makes it safe to reset a
device to its stock behaviour by deleting `$DEVICE_HOME/config.env`.
