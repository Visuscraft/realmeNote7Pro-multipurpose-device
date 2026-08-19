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
| `stock/` | Stock/default configuration: default settings, package list, and debloat lists. This is not stock-market data. |
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

## Using the device

### Find the phone's Wi-Fi IP address

The dashboard and optional SSH access are reached over your local Wi-Fi
network. To open them from another computer, first find the phone's Wi-Fi IP
address.

**In Termux, run:**

```sh
ip addr show wlan0 | grep 'inet '
```

Look for an address that usually looks like `192.168.x.y`. If that command does
not print anything, try the older network tool instead:

**In Termux, run:**

```sh
ifconfig wlan0
```

The phone and the computer you use to connect to it must be on the same Wi-Fi
network. The phone's IP address can change after Wi-Fi reconnects unless you set
a static or reserved address for the phone in your router.

### Open the dashboard from another device

By default, the dashboard only listens on the phone itself at
<http://127.0.0.1:8080/>. To open it from a computer on the same Wi-Fi network,
change the dashboard bind address, then start the `server` mode.

**In Termux, run:**

```sh
printf '\nDEVICE_DASHBOARD_BIND=0.0.0.0\n' >> ~/.realme-device/config.env
```

**In Termux, run:**

```sh
~/.realme-device/current/device/device.sh start server
```

On your computer, open `http://<phone-ip>:8080/` in a browser, replacing
`<phone-ip>` with the Wi-Fi IP address you found above.

Binding to `0.0.0.0` exposes the status page without a password to everyone on
that Wi-Fi network. Only do this on a network you trust.

### SSH into the phone (optional)

This project does not install or configure an SSH server. The `server` mode is
only the dashboard web server. If you want SSH access, install and start
Termux's OpenSSH server yourself.

**In Termux, run:**

```sh
pkg install -y openssh
```

**In Termux, run:**

```sh
passwd
```

**In Termux, run:**

```sh
sshd
```

Termux's `sshd` listens on port `8022`, not port `22`. Find your Termux
username before connecting:

**In Termux, run:**

```sh
whoami
```

On your computer, run this command, replacing `<username>` and `<phone-ip>` with
your Termux username and the phone's Wi-Fi IP address:

```sh
ssh -p 8022 <username>@<phone-ip>
```

After a phone reboot, start `sshd` again unless you add your own Termux:Boot hook
for it. For better security than a password, put your computer's public SSH key
in `~/.ssh/authorized_keys` in Termux and use key-based login.

### View what monitor mode records

`monitor` mode records device telemetry samples. It does not record audio,
video, or the screen. The samples are appended to
`~/.realme-device/state/samples.csv` with these columns:
`timestamp,battery_percentage,free_bytes,online`.

The default sample interval is 60 seconds. You can change it by setting
`DEVICE_MONITOR_INTERVAL` in `~/.realme-device/config.env`. The current
dashboard reads `status.json`, not this CSV file.

**In Termux, run:**

```sh
~/.realme-device/current/device/device.sh start monitor
```

**In Termux, run:**

```sh
tail -n 20 ~/.realme-device/state/samples.csv
```

### Understand and extend the dashboard

The dashboard reads `status.json`. That file is written by `device/status.sh`.
The visible dashboard cards are hardcoded in the `CARDS` array near the top of
`dashboards/app.js`.

To add a new dashboard item:

1. Edit `device/status.sh` so it writes the new field into `status.json`.
2. Edit `dashboards/app.js` and add a matching entry to the `CARDS` array.
3. Start the dashboard again.

**In Termux, run:**

```sh
~/.realme-device/current/device/device.sh start server
```

For example, if `device/status.sh` writes a new JSON field named
`battery_temperature_celsius`, add this card in `dashboards/app.js`:
`{ key: 'battery_temperature_celsius', label: 'battery temp', suffix: '°C' },`.
For byte values, use the existing byte formatter instead, for example
`{ key: 'cache_free_bytes', label: 'cache free', format: formatBytes },`.

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
| `DEVICE_MONITOR_INTERVAL` | `60` | Seconds between monitor telemetry samples. |
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
