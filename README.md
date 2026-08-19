# realmeNote7Pro-multipurpose-device

This guide helps you set up a realme Note 7 Pro as a device that keeps itself
updated. You do not need to know Git, programming, or Android development.

## First-device setup

Do these steps **on the realme Note 7 Pro**. Every command in this guide must be
entered in the **Termux app on that phone**—not in a browser, a text-message app,
or another Android terminal app.

### 1. Install the two required apps

Install these Android apps from the **same trusted source**, preferably F-Droid:

1. **Termux**
2. **Termux:Boot**

Using the same source avoids incompatible versions. Then open **Termux** once,
allow it to complete its initial setup, and wait until you see a prompt where you
can type. Leave Termux open while you work through the next steps.

### 2. Update Termux and install Git

Copy and paste these commands **one at a time in Termux**. Wait for each command
to finish before pasting the next one. If Termux asks a question, accept the
recommended option.

**In Termux, run:**

```sh
pkg update
```

**In Termux, run:**

```sh
pkg upgrade -y
```

**In Termux, run:**

```sh
pkg install -y git
```

### 3. Download and install the device software

First, return to Termux's main folder. Then download this project and run its
installer. Paste each command **one at a time in Termux**.

**In Termux, run:**

```sh
cd "$HOME"
```

**In Termux, run:**

```sh
git clone https://github.com/Visuscraft/realmeNote7Pro-multipurpose-device
```

**In Termux, run:**

```sh
bash "$HOME/realmeNote7Pro-multipurpose-device/deploy/install.sh"
```

The installer adds the other packages the device needs, saves its settings in
`~/.realme-device`, installs the automatic-start hook, downloads the latest
release when available, and starts the device software. Keep Termux open and
wait for the message starting with `installation finished`. The first run can
take a few minutes.

### 4. Check that it worked

After the installer finishes, check the status. It prints a short technical
status report; seeing output means the device software can run.

**In Termux, run:**

```sh
~/.realme-device/current/device/device.sh status
```

To watch messages from the automatic updater, run the following command in
Termux. New messages may appear as it checks for updates. Press `Ctrl+C` to stop
watching the log; this does not stop the updater.

**In Termux, run:**

```sh
tail -f ~/.realme-device/logs/updater.log
```

### 5. Allow it to work in the background and after a reboot

In Android Settings, find **Apps**, then open the battery settings for both
**Termux** and **Termux:Boot**. If your Android version offers battery
optimization, battery restrictions, or an “Unrestricted” setting, choose the
option that allows background use for both apps. Android settings names and
locations vary, so use the closest option shown on your phone.

The installer can start the device software now. For it to start automatically
after a phone reboot, **Termux:Boot must remain installed**. After rebooting,
give Android a moment to finish starting; Termux:Boot then starts the updater
and the saved device mode. You do not need to run the installer again after a
normal reboot.

## Troubleshooting

### “command not found”

Make sure you are typing in the Termux app and that you pasted the command
exactly. If `git` is not found, install it again:

**In Termux, run:**

```sh
pkg install -y git
```

If a command beginning with `~/.realme-device` is not found, the installer did
not finish. Follow the safe rerun steps below.

### Permission or access problem

Run the commands only in Termux. If Android reports that Termux or Termux:Boot
is restricted, revisit the background battery settings described above. If the
installer reports “Permission denied,” run it with the `bash` command shown in
step 3 rather than trying to open the file from an Android file manager.

If `git clone` says the destination already exists, do not download a second
copy. Use the existing copy and rerun the installer.

### Installation stopped or you closed Termux

Open Termux again, then rerun the installer from the project folder. It is safe
to rerun: your device-specific settings in `~/.realme-device/config.env` are
kept.

**In Termux, run:**

```sh
bash "$HOME/realmeNote7Pro-multipurpose-device/deploy/install.sh"
```

If it stops again, inspect the updater messages:

**In Termux, run:**

```sh
tail -f ~/.realme-device/logs/updater.log
```

## Repository layout

| Path | What it contains |
| --- | --- |
| `.github/workflows/release.yml` | Creates releases and updates `latest.json`. |
| `deploy/` | Installer, updater, debloater, and Termux:Boot hook. |
| `device/` | Device runtime, status collector, and shared code. |
| `modes/` | Device modes: `idle`, `monitor`, and `server`. |
| `stock/` | Default settings, package list, and debloat lists. |
| `dashboards/` | Local status dashboard and its web server. |
| `latest.json` | Update information checked by installed devices. |

## Daily use

Run these commands **in Termux on the realme Note 7 Pro**:

```sh
~/.realme-device/current/device/device.sh status
~/.realme-device/current/device/device.sh start monitor
~/.realme-device/current/deploy/update.sh --force
~/.realme-device/current/deploy/debloat.sh
~/.realme-device/current/deploy/debloat.sh --apply
tail -f ~/.realme-device/logs/updater.log
```

The debloat command without `--apply` only shows what would change. Before using
`--apply`, review that list carefully. You can undo its changes with:

**In Termux, run:**

```sh
~/.realme-device/current/deploy/debloat.sh --restore
```

The dashboard is served by the `server` mode at
<http://127.0.0.1:8080/>. Set `DEVICE_DASHBOARD_BIND=0.0.0.0` in
`~/.realme-device/config.env` to expose it on the local network.

## Configuration

`stock/config.env` holds the defaults. Advanced users can override them in
`~/.realme-device/config.env`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `DEVICE_REPO` | `Visuscraft/realmeNote7Pro-multipurpose-device` | Repository publishing the releases. |
| `DEVICE_MANIFEST_URL` | raw `latest.json` of `main` | Manifest checked by the updater. |
| `DEVICE_HOME` | `~/.realme-device` | Installation folder. |
| `DEVICE_UPDATE_INTERVAL` | `300` | Seconds between update checks. |
| `DEVICE_MODE` | `idle` | Mode started after boot. |
| `DEVICE_DASHBOARD_PORT` | `8080` | Dashboard port. |
| `DEVICE_KEEP_RELEASES` | `3` | Releases kept for rollback. |
| `DEVICE_DEBLOAT_BACKEND` | auto | `root`, `adb`, or `direct` backend for `deploy/debloat.sh`. |
| `DEVICE_BLOATWARE_LIST` | `stock/bloatware.txt` | Packages the debloater disables. |
| `DEVICE_SERVICES_LIST` | `stock/services.txt` | Services and settings the debloater turns off. |

## Safety

* Updates are downloaded over HTTPS and checked against the SHA-256 value in
  `latest.json`; a mismatch stops the update.
* A new release is prepared next to the running one before it is activated, so
  an interrupted update leaves the previous release available.
* Previous releases stay on the phone for rollback.
* The debloater disables packages rather than uninstalling them. It records its
  changes and `--restore` can undo them.

## License

[MIT](LICENSE)
