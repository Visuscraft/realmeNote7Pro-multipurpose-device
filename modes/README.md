# modes/

Every file in this directory is a mode the device can run. A mode is a plain
bash script that runs in the foreground until it receives `SIGTERM`.

| Mode | Description |
| --- | --- |
| `idle.sh` | Default mode. Keeps the runtime alive and refreshes the status file. |
| `monitor.sh` | Samples battery, free storage and connectivity into `state/samples.csv`. |
| `server.sh` | Serves the local dashboard on `DEVICE_DASHBOARD_PORT`. |

Start a mode with:

```sh
~/.realme-device/current/device/device.sh start monitor
```

The selected mode is stored in `state/mode` and is restored automatically after
a reboot or after a live update.

To add a mode, drop `modes/<name>.sh` in this directory; it becomes available
on every device with the next automatic update.
