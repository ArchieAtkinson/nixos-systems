# Fixed-policy bubblewrap sandbox for the OpenCode wrapper.
#
# There are no user-facing sandbox knobs: the policy lives here.
#
#   * closure-only /nix/store: baseline packages plus the closure of PATH
#   * no host root, /run, /proc host pids, Docker/DBus sockets
#   * private netns; Squid over a Unix-socket relay
#   * all USB/serial nodes present at launch are dev-bound (no hotplug)
#   * runtime host-loopback TCP ports from ~/.config/opencode/sandbox-ports
#   * git metadata read-only; hooks/config/alternates cannot be planted
#   * fake passwd/group/hosts and masked /proc/cmdline + boot id
{ pkgs, lib }:
let
  inherit (builtins)
    hashString
    isList
    replaceStrings
    substring
    ;

  dquote = s: "\"${replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s}\"";

  aclName = domain: "d_${substring 0 12 (hashString "sha256" domain)}";

  squidConfig = allowedDomains: ''
    visible_hostname ai-sandbox
    http_port 127.0.0.1:__PORT__

    acl CONNECT method CONNECT
    acl SSL_ports port 443
    acl Safe_ports port 80 443

    http_access deny CONNECT !SSL_ports
    http_access deny !Safe_ports

    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        domain: methods:
        let
          d = lib.removePrefix "*." domain;
          acl = aclName d;
          methodList = if isList methods then methods else [ methods ];
        in
        if methods == "*" || methodList == [ ] then
          ''
            acl ${acl} dstdomain .${d}
            http_access allow ${acl}
          ''
        else
          ''
            acl ${acl} dstdomain .${d}
            acl m_${acl} method ${lib.concatStringsSep " " methodList}
            http_access allow CONNECT ${acl}
            http_access allow ${acl} m_${acl}
          ''
      ) allowedDomains
    )}

    http_access deny all

    cache deny all
    cache_effective_user __USER__
    access_log none
    cache_log __RUNDIR__/cache.log
    pid_filename none
    coredump_dir __RUNDIR__
    shutdown_lifetime 1 seconds
  '';
in
{
  mkSandbox =
    {
      pkg,
      binName ? "opencode",
      outName ? "opencode-sandboxed",
      allowedPackages ? [ ],
      pathPrefix ? [ ],
      rwDirs ? [ ],
      roDirs ? [ ],
      env ? { },
      allowedDomains ? { },
    }:
    let
      sandboxTools = with pkgs; [
        bashInteractive
        cacert
        socat
      ];

      baselineClosure = pkgs.closureInfo {
        rootPaths = [ pkg ] ++ allowedPackages ++ pathPrefix ++ sandboxTools;
      };

      prefixPath = lib.optionalString (pathPrefix != [ ]) "${lib.makeBinPath pathPrefix}:";
      restPath = lib.makeBinPath allowedPackages;

      bash = "${pkgs.bashInteractive}/bin/bash";
      bwrap = "${pkgs.bubblewrap}/bin/bwrap";
      socat = "${pkgs.socat}/bin/socat";
      squid = "${pkgs.squid}/bin/squid";
      squidTemplate = pkgs.writeText "ai-sandbox-squid.conf" (squidConfig allowedDomains);

      deviceArgs = ''
        for pattern in /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* /dev/ttyAMA*; do
          while IFS= read -r dev; do
            [ -n "$dev" ] && args+=(--dev-bind-try "$dev" "$dev")
          done < <(compgen -G "$pattern" || true)
        done
        args+=(--dev-bind-try /dev/bus/usb /dev/bus/usb)
        args+=(--ro-bind-try /dev/serial /dev/serial)
      '';

      roArgs = lib.concatMapStringsSep "\n" (dir: ''
        dir=${dquote dir}
        if [ ! -e "$dir" ]; then
          printf 'ai-sandbox: read-only path %s is missing; refusing to launch\n' "$dir" >&2
          exit 1
        fi
        args+=(--ro-bind "$dir" "$dir")
        while IFS= read -r link; do
          target=$(readlink -f "$link" 2>/dev/null || true)
          case "$target" in
            /nix/store/*) args+=(--ro-bind "$target" "$target") ;;
          esac
        done < <(find "$dir" -type l 2>/dev/null || true)
      '') roDirs;

      rwArgs = lib.concatMapStringsSep "\n" (dir: ''
        dir=${dquote dir}
        mkdir -p "$dir"
        args+=(--bind "$dir" "$dir")
      '') rwDirs;

      envArgs = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (key: value: ''
          args+=(--setenv ${key} ${dquote value})
        '') env
      );

      relayScript = ''
        set -e
        ${socat} TCP-LISTEN:3128,bind=127.0.0.1,reuseaddr,fork \
          UNIX-CONNECT:/run/ai-relay/http.sock &
        for port in $AI_SANDBOX_FORWARD_PORTS; do
          ${socat} TCP-LISTEN:"$port",bind=127.0.0.1,reuseaddr,fork \
            UNIX-CONNECT:"/run/ai-relay/forward-$port.sock" &
        done
        for port in 3128 $AI_SANDBOX_FORWARD_PORTS; do
          for _ in {1..50}; do
            if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
              exec 3>&-
              break
            fi
            sleep 0.1
          done
          if ! (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
            printf 'ai-sandbox: relay is not listening on port %s\n' "$port" >&2
            exit 1
          fi
        done
        exec "$@"
      '';

      app = [
        bash
        "-c"
        relayScript
        "ai-sandbox"
        (lib.getExe' pkg binName)
      ];

      script = ''
        set -euo pipefail

        export PATH="${
          lib.makeBinPath [
            pkgs.bubblewrap
            pkgs.squid
            pkgs.socat
            pkgs.coreutils
            pkgs.gnused
            pkgs.gnugrep
            pkgs.findutils
            pkgs.gitMinimal
            pkgs.bashInteractive
          ]
        }:$PATH"

        runtime=$(mktemp -d "''${TMPDIR:-/tmp}/ai-sandbox.XXXXXX")
        squid_pid=""
        relay_pids=()

        cleanup() {
          for pid in "''${relay_pids[@]}"; do
            kill "$pid" 2>/dev/null || true
          done
          [ -n "$squid_pid" ] && kill "$squid_pid" 2>/dev/null || true
          rm -rf "$runtime"
        }
        trap cleanup EXIT

        workspace=$(pwd -P)
        case "$workspace" in
          /|/nix|/nix/store|/nix/store/*|"$HOME"|/home|/root|/etc|/etc/*|/usr|/usr/*|/var|/var/*|/run|/run/*|/proc|/proc/*|/dev|/dev/*)
            printf 'ai-sandbox: refusing to bind workspace %s (launch from a project directory)\n' "$workspace" >&2
            exit 1
            ;;
        esac

        args=(
          --dir /nix
          --dir /nix/store
          --dir /etc
          --dir /dev
          --dir /proc
          --dir /tmp
          --dir /var
          --dir /var/tmp
          --dir /home
          --dir /run
          --dir /usr
          --dir /usr/bin
          --dir /bin
          --dir /sys
          --ro-bind-try /sys /sys
          --proc /proc
          --dev /dev
          --perms 1777 --tmpfs /dev/shm
          --perms 1777 --tmpfs /tmp
          --perms 1777 --tmpfs /var/tmp
          --tmpfs /home
          --dir "$HOME"
          --clearenv
          --hostname sandbox
          --die-with-parent
          --new-session
          --unshare-user
          --unshare-ipc
          --unshare-pid
          --unshare-uts
          --unshare-cgroup
          --unshare-net
        )

        while IFS= read -r p; do
          [ -n "$p" ] && args+=(--ro-bind "$p" "$p")
        done < ${baselineClosure}/store-paths

        # Closure of the current PATH: nix develop tools and NixOS default
        # apps. Nothing else from the store is visible.
        roots="$runtime/roots"
        closure_file="$runtime/closure"
        : > "$roots"

        printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r entry; do
          case "$entry" in
            /nix/store/*/bin)
              dirname "$entry"
              ;;
            /run/current-system/sw/bin)
              for link in "$entry"/*; do
                [ -e "$link" ] || continue
                target=$(readlink -f "$link" 2>/dev/null || true)
                case "$target" in
                  /nix/store/*) printf '%s\n' "$target" ;;
                esac
              done
              ;;
          esac
        done | sort -u > "$roots"

        nix_store=/nix/var/nix/profiles/default/bin/nix-store
        if [ ! -x "$nix_store" ]; then
          nix_store="$(command -v nix-store || true)"
        fi

        : > "$closure_file"
        if [ -n "$nix_store" ] && [ -s "$roots" ]; then
          mapfile -t roots_arr < "$roots"
          "$nix_store" --query --requisites "''${roots_arr[@]}" \
            | sort -u > "$closure_file" || true
        else
          cp "$roots" "$closure_file" 2>/dev/null || true
        fi

        while IFS= read -r p; do
          [ -n "$p" ] && args+=(--ro-bind "$p" "$p")
        done < "$closure_file"

        args+=(--ro-bind-try /run/current-system/sw/bin /run/current-system/sw/bin)

        # Git: keep the object database writable, but make hooks/config/
        # alternates read-only. Also protect worktree metadata.
        git_root=$(git -C "$workspace" rev-parse --show-toplevel 2>/dev/null || true)
        if [ -n "$git_root" ]; then
          git_common=$(git -C "$git_root" rev-parse --git-common-dir 2>/dev/null || true)
          case "$git_common" in
            /*) ;;
            *) git_common="$git_root/$git_common" ;;
          esac
          git_common=$(realpath -e "$git_common" 2>/dev/null || printf '%s' "$git_common")

          case "$git_root" in
            /|"$HOME"|/home|/root)
              printf 'ai-sandbox: refusing to bind repository root %s\n' "$git_root" >&2
              exit 1
              ;;
          esac
          [ "$git_root" != "$workspace" ] && args+=(--bind "$git_root" "$git_root")
          args+=(--bind "$git_common" "$git_common")

          empty_dir="$runtime/empty-dir"
          empty_file="$runtime/empty-file"
          mkdir -p "$empty_dir"
          : > "$empty_file"

          for protected in \
            "$git_common/hooks" \
            "$git_common/config" \
            "$git_common/objects/info/alternates"; do
            if [ -e "$protected" ]; then
              args+=(--ro-bind "$protected" "$protected")
            else
              case "$protected" in
                */hooks) args+=(--ro-bind "$empty_dir" "$protected") ;;
                *) args+=(--ro-bind "$empty_file" "$protected") ;;
              esac
            fi
          done
        fi

        # Fake identity files; keep the host kernel/host entries out.
        user=$(id -un)
        uid=$(id -u)
        gid=$(id -g)
        printf '%s:x:%s:%s::%s:/bin/sh\n' "$user" "$uid" "$gid" "$HOME" > "$runtime/passwd"
        printf '%s:x:%s:\n' "$user" "$gid" > "$runtime/group"
        printf '127.0.0.1 localhost\n::1 localhost\n' > "$runtime/hosts"
        : > "$runtime/empty"

        args+=(
          --ro-bind "$runtime/passwd" /etc/passwd
          --ro-bind "$runtime/group" /etc/group
          --ro-bind "$runtime/hosts" /etc/hosts
          --ro-bind "$runtime/empty" /proc/cmdline
          --ro-bind "$runtime/empty" /proc/sys/kernel/random/boot_id
          --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf
          --ro-bind-try /etc/ssl/certs /etc/ssl/certs
          --ro-bind-try /etc/static/ssl /etc/static/ssl
          --ro-bind-try /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf
          --ro-bind-try /etc/pki /etc/pki
          --ro-bind-try /etc/localtime /etc/localtime
          --ro-bind-try /etc/services /etc/services
          --ro-bind-try /etc/resolv.conf /etc/resolv.conf
          --ro-bind-try /usr/bin/env /usr/bin/env
          --ro-bind-try /bin/sh /bin/sh
          --ro-bind-try /run/current-system/sw/share/terminfo /run/current-system/sw/share/terminfo
          --bind "$workspace" "$workspace"
        )

        ${roArgs}
        ${rwArgs}

        ${deviceArgs}

        args+=(
          --setenv HOME "$HOME"
          --setenv USER "''${USER:-$(id -un)}"
          --setenv TERM "''${TERM:-dumb}"
          --setenv LANG "''${LANG:-C.UTF-8}"
          --setenv TERMINFO_DIRS "/run/current-system/sw/share/terminfo"
          --setenv TMPDIR /tmp
          --setenv PATH ${dquote "${prefixPath}$PATH:${restPath}"}
        )

        ${envArgs}

        # Preserve the build variables a nix develop shell exports; --clearenv
        # otherwise drops them and cross/embedded builds fail.
        for var in \
          CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH \
          PKG_CONFIG_PATH CMAKE_PREFIX_PATH \
          NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_CC \
          CC CXX AR RANLIB LD NM STRIP OBJCOPY RUSTFLAGS; do
          val="''${!var:-}"
          [ -n "$val" ] && args+=(--setenv "$var" "$val")
        done

        # Runtime host-loopback ports. The file is read on the host before
        # bwrap starts; the sandbox only sees the resulting relay sockets.
        ports_file="$HOME/.config/opencode/sandbox-ports"
        ports=""
        ports_seen=0
        if [ -r "$ports_file" ]; then
          ports_seen=1
          while IFS= read -r line; do
            line="''${line%%#*}"
            line=$(printf '%s' "$line" | tr -d '[:space:]')
            case "$line" in
              ""|*[!0-9]*) continue ;;
            esac
            if [ "$line" -ge 1 ] && [ "$line" -le 65535 ] && [ "$line" -ne 3128 ]; then
              ports="$ports $line"
            fi
          done < "$ports_file"
        fi
        if [ "$ports_seen" -eq 0 ]; then
          ports="1883 8883"
        fi
        forward_ports=$(printf '%s\n' $ports | sort -nu | tr '\n' ' ')
        forward_ports="''${forward_ports% }"

        # Squid on a per-launch loopback port.
        squid_port="''${AI_SANDBOX_PROXY_PORT:-$(( 30000 + RANDOM % 20000 ))}"
        sed -e "s|__PORT__|$squid_port|g" \
          -e "s|__RUNDIR__|$runtime|g" \
          -e "s|__USER__|$(id -un)|g" \
          ${squidTemplate} > "$runtime/squid.conf"
        ${squid} -N -f "$runtime/squid.conf" &
        squid_pid=$!
        for _ in $(seq 1 100); do
          if (exec 3<>"/dev/tcp/127.0.0.1/$squid_port") 2>/dev/null; then
            exec 3>&-
            break
          fi
          sleep 0.1
        done
        if ! kill -0 "$squid_pid" 2>/dev/null; then
          printf 'ai-sandbox: Squid failed to start; see %s\n' "$runtime/cache.log" >&2
          cat "$runtime/cache.log" >&2 || true
          exit 1
        fi

        relay_dir="$runtime/relay"
        mkdir -p "$relay_dir"
        chmod 700 "$relay_dir"
        ${socat} "UNIX-LISTEN:$relay_dir/http.sock,fork,unlink-early,mode=600" \
          "TCP:127.0.0.1:$squid_port" &
        relay_pids+=($!)

        for port in $forward_ports; do
          ${socat} "UNIX-LISTEN:$relay_dir/forward-$port.sock,fork,unlink-early,mode=600" \
            "TCP:127.0.0.1:$port" &
          relay_pids+=($!)
        done

        for sock in "$relay_dir/http.sock" $(
          for port in $forward_ports; do printf '%s\n' "$relay_dir/forward-$port.sock"; done
        ); do
          for _ in $(seq 1 100); do
            [ -S "$sock" ] && break
            sleep 0.05
          done
          if [ ! -S "$sock" ]; then
            printf 'ai-sandbox: relay socket %s was not created\n' "$sock" >&2
            exit 1
          fi
        done

        args+=(
          --ro-bind "$relay_dir" /run/ai-relay
          --setenv HTTP_PROXY "http://127.0.0.1:3128"
          --setenv HTTPS_PROXY "http://127.0.0.1:3128"
          --setenv ALL_PROXY "http://127.0.0.1:3128"
          --setenv http_proxy "http://127.0.0.1:3128"
          --setenv https_proxy "http://127.0.0.1:3128"
          --setenv all_proxy "http://127.0.0.1:3128"
          --setenv NO_PROXY "localhost,127.0.0.1,::1"
          --setenv no_proxy "localhost,127.0.0.1,::1"
          --setenv AI_SANDBOX_FORWARD_PORTS "$forward_ports"
        )

        args+=(--chdir "$workspace")

        status=0
        ${bwrap} "''${args[@]}" -- "''${app[@]}" "$@" || status=$?
        exit "$status"
      '';
    in
    pkgs.writeShellScriptBin outName script;
}
