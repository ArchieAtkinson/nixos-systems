---
name: Embedded debug
description: Debug serial, USB, and network-attached embedded devices inside the sandbox
---

# Embedded debug

## What the sandbox provides

- USB and serial nodes present **at launch**: `/dev/serial/by-id/...`,
  `/dev/ttyUSB*`, `/dev/ttyACM*`, `/dev/ttyS*`, `/dev/ttyAMA*`, `/dev/bus/usb`.
- `/sys` read-only, so libusb can enumerate devices.
- Host-loopback TCP ports listed in `~/.config/opencode/sandbox-ports`, reachable
  at `127.0.0.1:<port>`.

## Workflow

1. **Confirm the device is visible** before debugging logic:
   `ls /dev/serial/by-id/`, `lsusb`. Use the stable `by-id` path, not
   `/dev/ttyUSB0`.
2. **No hotplug.** If the device was plugged in after launch it will not appear;
   ask the user to replug and relaunch the sandbox rather than retrying.
3. **Serial:** read with `tio -b <baud> /dev/serial/by-id/...` or capture with
   `python3` when `tio` is unavailable. Flash with `esptool.py --port
   /dev/serial/by-id/...`. Neither `tio` nor `esptool` is preinstalled; install
   the one you need with `uv` into a workspace venv, and report a genuine
   installation failure rather than treating the missing tool as blocked.
4. **Network:** host services (for example a Mosquitto broker) are only reachable
   through `sandbox-ports`. If a connection fails, check the port is in
   `~/.config/opencode/sandbox-ports` (read-only to you) before debugging the
   device.
5. **Report** the device path, baud rate, and the exact command that failed.

## Rules

- Do not assume LAN access; there is none.
- Missing device or port is a sandbox fact, not a bug — report it and ask.
- Do not sidestep a blocked device by reimplementing its protocol against a mock
  unless the user asks.
