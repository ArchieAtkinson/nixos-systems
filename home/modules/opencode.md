# OpenCode sandbox

OpenCode runs in a bubblewrap sandbox under a root-owned managed policy. The
filesystem view and the filtering proxy are the boundary; the policy shapes
behaviour, it is not the boundary.

The sandbox is built from standard tools only: `bwrap` for namespaces and
mounts, Squid for the domain allowlist, and `socat` to relay traffic across an
otherwise empty network namespace. There is no custom proxy, no TLS
interception, and no host firewall rules. The wrapper is built by
`home/lib/bwrap-sandbox.nix` (via `home/lib/opencode-sandbox.nix`) and used in
two ways:

- the global `opencode` from `home/modules/opencode.nix`, optionally in
  reduced-nix mode so it picks up the dev shell you launch it from, and
- per-project wrappers from a project's own dev shell (see below).

## Hardening

- **Filesystem** — the workspace, the OpenCode data dirs (`rwDirs`), and the
  config dir (`roDirs`) are mounted; `$HOME` and `/tmp` are tmpfs. Extra
  read-only context is opt-in through `extraReadOnlyDirs`, and reduced-nix mode
  adds the Nix store (see Dev shells).
- **Packages** — a lean baseline (coreutils, gitMinimal, ripgrep, fd, gnused,
  gnugrep, findutils, diffutils, gawk, jq, less, which, curl, `python3`, `uv`,
  and `yq`). Project toolchains come from the launching dev shell
  (reduced-nix mode) or from a per-project wrapper.
- **Network** — per-launch Squid with an `allowedDomains` allowlist: the
  provider and search tooling; package registries (npm, PyPI, crates.io, the
  Nix cache); GitHub; and a curated read-only set (Wikipedia/Wikimedia/
  Wikidata, Kagi, arXiv/DOI/PubMed and other academic hosts,
  IETF/RFC/W3C/WHATWG/Unicode, language and library docs, Stack Exchange,
  Hacker News, archive.org, and a few news sources). Everything else is
  blocked. `internet = "open"` drops the allowlist and the private network
  namespace.
  The sandbox runs in a private network namespace with only loopback; a
  `socat` relay carries HTTP proxy traffic over a Unix socket to Squid on the
  host. Squid resolves names and sees only the allowed domains, so direct
  connections from inside the sandbox have no route. TLS is tunnelled with
  `CONNECT`; it is not intercepted, so method lists apply only to plain HTTP
  and are not enforced for HTTPS.
- **Devices** — tty nodes matching `deviceGlobs` (default `/dev/ttyUSB*`,
  `/dev/ttyACM*`, `/dev/ttyS*`, `/dev/ttyAMA*`) are passed with
  `--dev-bind-try`; `/dev/serial` is mounted read-only. Only nodes present at
  launch are visible, so replugging a device requires relaunching the
  sandbox. With `serial-tty` udev rules the nodes are mode 0666, which is
  required because bwrap's user namespace drops supplementary groups
  (`dialout` does not survive). USB debug probes are not ttys; if you need
  `probe-rs` over USB, add `/dev/bus/usb/*/*` to `deviceGlobs` (and the
  matching udev access rule).
- **Secrets** — API key injected from sops into env at launch, never in the
  store. Policy denies env/secret reads and `external_directory`.
- **Policy** — shell, search, and fetch run without prompting; the sandbox view
  and proxy are the controls. The curated hosts remain explicit `webfetch`
  allow rules, and secret, env, and `/proc` reads are hard `tool.use` denials.
  The provider is pinned to `opencode-go`. The `explore`, `researcher`, and
  `reviewer` subagents are permitted; all others are hard-denied.
- **Fail-closed** — the wrapper refuses to launch if the policy/key is missing,
  invalid, or missing sentinel rules.

## Subagents

Subagents are child sessions on the same in-sandbox server, so they share the
filesystem view and the proxy; they cannot widen the boundary. Two are defined
in the managed policy and one is built in:

- `explore` (built-in) — read-only search.
- `researcher` — reads code and web sources; `edit` and `shell` denied.
- `reviewer` — reviews changes; `edit` and `shell` denied.

Nesting depth is one, so a subagent cannot launch another.

## Dev shells (reduced nix)

The sandbox never gets the nix daemon, so `nix develop`/`nix build` do not run
inside it. Instead, `modules.opencode.devShellMode` lets the **global** wrapper
use the shell you launch it from:

- `"off"` (default) — only the sandbox package closure is mounted.
- `"store"` — the whole Nix store is mounted read-only and the launching
  shell's `PATH` is inherited. `nix develop` → `opencode` gives the agent that
  project's tools, with no per-project wrapper.
- `"closure"` — the same, but a host-side step stages symlinks to the closure of
  the store paths on `PATH`, so only those are bound. Narrower than binding the
  whole store, but it costs a host-side `nix-store --query --requisites` step and
  a per-launch closure scan. If `nix-store` is unavailable it binds the direct
  `PATH` store paths without computing their closure; if nothing is staged, only
  the baseline is available.

Both enabled modes keep egress filtered and expose no host sockets or daemon
(the only socket in the sandbox is the read-only relay to the per-launch
proxy). `PATH` becomes a wrapped `bash`, then the launching shell's `PATH` (so the dev
shell's tools take precedence), then the sandbox baseline as a fallback. Direct
store-path entries (what `nix develop` puts on `PATH`) resolve; entries routed
through `~/.nix-profile` or `/nix/var` do not, since those roots are not
mounted. The trade is that the store becomes readable and executable — the
agent can see which packages you have and run any store binary.

## Per-project dev shells (optional)

The global wrapper cannot pick up an arbitrary dev shell at runtime: the bind
set is fixed when the wrapper is built. To give a project its own toolchain,
build a wrapper in the project's flake and put it in the dev shell:

```nix
# project/flake.nix
{
  description = "Sandboxed OpenCode for this project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Exports lib.mkOpencodeSandbox. While developing locally, use a path
    # input instead: url = "path:/home/archie/nixos-systems/home";
    nixos-systems = {
      url = "github:archie-judd/nixos-systems?dir=home";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Match the OpenCode pin the global config uses.
    opencode.url = "github:anomalyco/opencode/v2.0.22";
  };

  outputs = { self, nixpkgs, nixos-systems, opencode, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = nixpkgs.lib;

      # Whatever the project needs to build and test.
      projectTools = with pkgs; [ nodejs_22 pnpm just ];

      # Upstream completions step fails, so strip postInstall (same as the
      # global module).
      opencodePkg = opencode.packages.${system}.opencode.overrideAttrs (_: {
        postInstall = "";
      });

      opencode-sandboxed = (nixos-systems.lib.mkOpencodeSandbox {
        inherit pkgs lib;
      }) {
        pkg = opencodePkg;

        # Added to the lean baseline inside the sandbox.
        extraPackages = projectTools;

        # Merged over the curated default allowlist; the base list still
        # applies unless `allowedDomains` is overridden entirely.
        extraDomains = {
          "nodejs.org" = [ "GET" "HEAD" ];
        };

        # Discover this project's AGENTS.md / .opencode (hidden by default).
        disableProjectConfig = false;

        # Optional read-only context, expanded at launch:
        # extraReadOnlyDirs = [ "$HOME/dotfiles" ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = projectTools ++ [ opencode-sandboxed ];
      };
    };
}
```

A minimal wrapper for a project that only needs extra tooling and no network
changes:

```nix
opencode-sandboxed = (nixos-systems.lib.mkOpencodeSandbox {
  inherit pkgs lib;
}) {
  pkg = opencodePkg;
  extraPackages = with pkgs; [ duckdb miller ];
};
```

Then `nix develop` and run `opencode` (the wrapper is installed under that
name). The curated allowlist applies unless `allowedDomains` is overridden, and
project config is only disabled when `disableProjectConfig` stays at its
default `true`.

## Trade-offs

- **Key in env** — the agent can read `$OPENCODE_API_KEY`. Safe only while
  egress is restricted (no attacker-controlled host is reachable). A broad
  `"*"` GET allowlist would allow URL-based exfiltration, so the allowlist
  stays curated. Secret masking is deferred.
- **No review prompt** — shell runs without asking; the only hard denials are
  the secret/env/`/proc` patterns. A prompt-injected model can therefore run any
  command the sandbox permits, with no human gate. The fs view and proxy are the
  controls.
- **Scripting runtime** — `python3` and `uv` mean a command prompt would be a
  weak gate anyway (a `python -c` is not readable at a glance). This is a
  policy-layer trade-off, not a boundary one; the fs view and proxy still
  bound what any interpreter can do.
- **Runtime dirs** — `extraReadOnlyDirs` and per-project packages are
  build-time. Symlinks inside a declared dir are only followed into the Nix
  store; symlinks to home paths are ignored. Per-session, arbitrary mounts are
  not supported.
- **Domain-only proxy** — because HTTPS is tunnelled rather than intercepted,
  `allowedDomains` values that list HTTP methods are not enforced for HTTPS.
  This is a deliberate trade for dropping the custom MITM proxy and CA.
- **TTY hotplug** — device binds are fixed at launch. A replugged or
  newly-attached serial device is invisible until the sandbox is restarted.
  The udev `serial-tty` option sets serial nodes to mode 0666, which is
  visible to every local user; `dialout` alone cannot work because bwrap's
  user namespace drops supplementary groups.
- **Reduced nix** — `devShellMode = "store"` exposes the whole store read-only
  (fingerprinting; any store binary runnable) and inherits the launch shell's
  `PATH`; profile symlinks under `~/.nix-profile` or `/nix/var` are not mounted,
  so only direct store-path `PATH` entries resolve. `"closure"` narrows the bind
  to the closure of the current `PATH`, at the cost of a host-side `nix-store`
  step and a per-launch closure scan. Neither mode exposes the daemon, so builds
  and fetches still fail inside.
- **Single provider** — `opencode-go` only.
