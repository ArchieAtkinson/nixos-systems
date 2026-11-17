# OpenCode sandbox

OpenCode runs in a fixed-policy bubblewrap sandbox under a root-owned managed
policy. The filesystem view and the egress relay are the boundary; the policy
shapes behaviour, it is not the boundary.

The policy is intentionally not configurable. This is a single-user,
trusted-hardware embedded development machine. There are no per-project
wrappers and no sandbox knobs.

The builder is `home/lib/bwrap-sandbox.nix`; `home/lib/opencode-sandbox.nix`
adds the managed-policy guard and the OpenCode-specific environment.

## Hardening

- **Filesystem** — the workspace, OpenCode state dirs, and the OpenCode config
  dir are mounted; `$HOME`, `/tmp`, `/var/tmp`, and `/dev/shm` are tmpfs.
  The host root, `/run`, `/proc` host pids, Docker sockets, and DBus are not
  visible.
- **Programs** — `/nix/store` contains only the closure of the baseline
  packages and the closure of the store paths currently on `PATH`. NixOS
  default apps under `/run/current-system/sw/bin` are included. The rest of
  the store is not visible, so the agent cannot discover or run unrelated
  programs.
- **Network** — a private network namespace with only loopback. HTTP(S) goes
  through a per-launch Squid over a Unix-socket relay. The domain allowlist is
  the curated set in `home/lib/opencode-sandbox.nix`; anything not listed is
  blocked. HTTPS is tunnelled with `CONNECT`, not intercepted, so method lists
  are enforced only for plain HTTP. Name resolution happens in Squid on the
  host; a DNS lookup attempted inside the sandbox fails immediately.
- **Host ports** — the sandbox can reach explicitly configured host-loopback
  TCP ports through the same relay mechanism. The list is read at launch from
  `~/.config/opencode/sandbox-ports`; the file is not writable by the agent.
  If the file is missing or empty, no host ports are forwarded. The host
  target is always `127.0.0.1:<port>`.
- **Devices** — every USB and serial node present at launch is visible:
  `/dev/bus/usb`, `/dev/serial`, `/dev/ttyUSB*`, `/dev/ttyACM*`, `/dev/ttyS*`,
  and `/dev/ttyAMA*`. `/sys` is mounted read-only so libusb can enumerate USB
  devices; there is no udev inside the sandbox. Block devices (`/dev/sd*`,
  `/dev/nvme*`, `/dev/mmcblk*`), input devices, DRM, video, and KVM are not
  bound.
- **Hotplug** — not supported. A device plugged in after launch requires
  restarting the sandbox. There is no udev inside the sandbox, so libudev
  hotplug events do not work.
- **Secrets** — the API key is copied from sops into a launch-time file
  (mode 0600, inside the per-launch runtime dir), bound read-only into the
  sandbox, and exported by the relay before OpenCode starts, so it never
  enters the store or bwrap's argv (`/proc/1/cmdline`). The agent can still
  read it from `$OPENCODE_API_KEY` or from `/run/ai-secrets`; that is the
  documented trade-off. Policy denies env/secret reads and
  `external_directory`.
- **Policy** — shell, search, and fetch run without prompting; the sandbox view
  and egress relay are the controls. The provider is pinned to `opencode-go`.
- **Fail-closed** — the wrapper refuses to launch if the policy or key is
  missing, invalid, or missing sentinel rules.

## Git protection

The workspace is writable, but git metadata is not left open to hook/alternate
injection:

- the repository root and the git common directory are writable;
- `.git/hooks`, `.git/config`, and `objects/info/alternates` are read-only
  (empty files/directories are bound if they do not exist);
- the agent therefore cannot plant a hook, change `core.hooksPath`, add an
  alias, or point the object database at a directory it controls.

## Device permissions

bwrap drops supplementary groups, so `dialout` does not survive into the
sandbox. `os/modules/udev-rules.nix` installs a fixed udev rule that gives
`archie` an ACL on USB and serial nodes. This is deliberately single-user.
There is no `0666` blanket rule for USB devices.

## Host ports

Example `~/.config/opencode/sandbox-ports`:

```text
# host-loopback TCP ports exposed inside the sandbox at the same number
1883
8883
```

The file is read on the host before bwrap starts. Only `127.0.0.1:<port>` is
reachable; there is no general LAN access. The sandbox sees the ports on its
own loopback. One port per line (whitespace-separated entries also work);
entries that are non-numeric, out of range, or `3128` are ignored with a
warning.

For an ESP32 with Ethernet and USB serial:

```text
Host:
  Mosquitto on 127.0.0.1:1883, reachable on the LAN
  ESP32 connects to the host over Ethernet

Sandbox:
  mosquitto_sub -h 127.0.0.1 -t 'esp32/#'
  esptool.py --port /dev/serial/by-id/... flash
  tio -b 115200 /dev/serial/by-id/...
```

The broker stays on the host. The ESP32 reaches it over the LAN; the sandbox
reaches it through the fixed host-loopback relay.

## Trade-offs

- **All USB/serial** — raw USB includes HID and storage interfaces. This is
  acceptable only because the machine and hardware are trusted and single-user.
- **No hotplug** — relaunch after replugging. No udev events or dynamic device
  nodes inside.
- **Domain-only HTTPS** — the old MITM proxy could restrict methods and bodies;
  this design does not intercept TLS. The curated domain list is the control.
- **No AF_UNIX seccomp** — the private network namespace isolates abstract
  sockets and there is no host `/run`, but pathname sockets in the workspace
  are reachable. This is a deliberate simplicity trade.
- **Key in env** — the agent can read `$OPENCODE_API_KEY`. Safe only while
  egress is restricted to the curated list.
- **No review prompt** — shell runs without asking; the filesystem view and
  egress relay are the controls.
