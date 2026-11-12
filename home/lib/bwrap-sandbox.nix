# Minimal bubblewrap sandbox for the OpenCode wrapper.
#
# Security boundary:
#   * bwrap user/mount/PID/IPC/UTS/cgroup namespaces, empty root, tmpfs home.
#   * restricted egress: private netns plus a Unix-socket relay to a per-launch
#     Squid. The sandbox has no route to the host or the internet except the
#     relay socket, and Squid only allows the generated domain ACLs.
#   * tty nodes are explicitly dev-bound. Everything else in /dev is the
#     minimal set bwrap creates.
#
# Only standard tools are involved (bubblewrap, Squid, socat); there is no
# TLS interception, no host firewall rules, and no custom proxy protocol.
{ pkgs, lib }:
let
  inherit (builtins)
    hashString
    isList
    replaceStrings
    substring
    ;

  # Quote a Nix string for a shell double-quoted context while leaving `$`
  # expansion intact, so values such as "$(cat /run/secrets/...)" and "$HOME"
  # are evaluated on the host at launch.
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
      internet ? "restricted",
      deviceGlobs ? [
        "/dev/ttyUSB*"
        "/dev/ttyACM*"
        "/dev/ttyS*"
        "/dev/ttyAMA*"
      ],
      devShellMode ? "off",
    }:
    let
      sandboxTools = with pkgs; [
        bashInteractive
        cacert
        socat
      ];

      closure = pkgs.closureInfo {
        rootPaths = [ pkg ] ++ allowedPackages ++ pathPrefix ++ sandboxTools;
      };

      prefixPath = lib.optionalString (pathPrefix != [ ]) "${lib.makeBinPath pathPrefix}:";
      restPath = lib.makeBinPath allowedPackages;

      bash = "${pkgs.bashInteractive}/bin/bash";
      bwrap = "${pkgs.bubblewrap}/bin/bwrap";
      socat = "${pkgs.socat}/bin/socat";
      squid = "${pkgs.squid}/bin/squid";

      restricted = internet == "restricted";

      squidTemplate = pkgs.writeText "ai-sandbox-squid.conf" (squidConfig allowedDomains);

      pathValue =
        if devShellMode == "off" then
          "${prefixPath}${restPath}"
        else if devShellMode == "store" then
          "${prefixPath}$PATH:${restPath}"
        else if devShellMode == "closure" then
          "${prefixPath}$stage:$PATH:${restPath}"
        else
          throw "bwrap-sandbox: unknown devShellMode ${devShellMode}";

      stagingScript = lib.optionalString (devShellMode == "closure") ''
        new="$stage.new.$$"
        rm -rf "$new"
        mkdir -p "$new"

        printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r entry; do
          case "$entry" in
            /nix/store/*/bin) dirname "$entry" ;;
          esac
        done | sort -u > "$new/.roots" || true

        nix_store=/nix/var/nix/profiles/default/bin/nix-store
        if [ ! -x "$nix_store" ]; then
          nix_store="$(command -v nix-store || true)"
        fi

        : > "$new/.closure"
        if [ -n "$nix_store" ] && [ -s "$new/.roots" ]; then
          mapfile -t roots < "$new/.roots"
          "$nix_store" --query --requisites "''${roots[@]}" 2>/dev/null \
            | sort -u > "$new/.closure" || true
        else
          cp "$new/.roots" "$new/.closure" 2>/dev/null || true
        fi

        while IFS= read -r p; do
          if [ -n "$p" ]; then
            ln -sfn "$p" "$new/$(basename "$p")"
          fi
        done < "$new/.closure"
        rm -f "$new/.roots" "$new/.closure"

        rm -rf "$stage"
        mv -T "$new" "$stage"
      '';

      proxySetup = lib.optionalString restricted ''
        runtime=$(mktemp -d "''${TMPDIR:-/tmp}/ai-sandbox.XXXXXX")
        port="''${AI_SANDBOX_PROXY_PORT:-$(( 30000 + RANDOM % 20000 ))}"
        user=$(id -un)
        sed -e "s|__PORT__|$port|g" \
          -e "s|__RUNDIR__|$runtime|g" \
          -e "s|__USER__|$user|g" \
          ${squidTemplate} > "$runtime/squid.conf"

        ${squid} -N -f "$runtime/squid.conf" &
        squid_pid=$!

        for _ in $(seq 1 100); do
          if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
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

        sockdir="$runtime/sock"
        mkdir -p "$sockdir"
        chmod 700 "$sockdir"
        sock="$sockdir/proxy.sock"
        ${socat} "UNIX-LISTEN:$sock,fork,unlink-early,mode=600" \
          "TCP:127.0.0.1:$port" &
        relay_pid=$!

        for _ in $(seq 1 100); do
          [ -S "$sock" ] && break
          kill -0 "$relay_pid" 2>/dev/null || break
          sleep 0.1
        done
        if [ ! -S "$sock" ]; then
          printf 'ai-sandbox: proxy relay failed to start\n' >&2
          exit 1
        fi

        args+=(
          --unshare-net
          --ro-bind "$sockdir" /run/ai-proxy
          --setenv HTTP_PROXY "http://127.0.0.1:3128"
          --setenv HTTPS_PROXY "http://127.0.0.1:3128"
          --setenv ALL_PROXY "http://127.0.0.1:3128"
          --setenv http_proxy "http://127.0.0.1:3128"
          --setenv https_proxy "http://127.0.0.1:3128"
          --setenv all_proxy "http://127.0.0.1:3128"
          --setenv NO_PROXY "localhost,127.0.0.1,::1"
          --setenv no_proxy "localhost,127.0.0.1,::1"
        )
      '';

      relayScript = ''
        set -e
        ${socat} TCP-LISTEN:3128,bind=127.0.0.1,reuseaddr,fork \
          UNIX-CONNECT:/run/ai-proxy/proxy.sock &
        for _ in {1..50}; do
          if (exec 3<>/dev/tcp/127.0.0.1/3128) 2>/dev/null; then
            exec 3>&-
            break
          fi
          sleep 0.1
        done
        if ! (exec 3<>/dev/tcp/127.0.0.1/3128) 2>/dev/null; then
          printf 'ai-sandbox: proxy relay is not listening\n' >&2
          exit 1
        fi
        exec "$@"
      '';

      app =
        if restricted then
          [
            bash
            "-c"
            relayScript
            "ai-sandbox"
            (lib.getExe' pkg binName)
          ]
        else
          [ (lib.getExe' pkg binName) ];

      deviceArgs = lib.concatMapStringsSep "\n" (pattern: ''
        while IFS= read -r dev; do
          [ -n "$dev" ] && args+=(--dev-bind-try "$dev" "$dev")
        done < <(compgen -G ${lib.escapeShellArg pattern} || true)
      '') deviceGlobs;

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

        runtime=""
        squid_pid=""
        relay_pid=""
        stage="$HOME/.cache/opencode-devshell"

        cleanup() {
          [ -n "$relay_pid" ] && kill "$relay_pid" 2>/dev/null || true
          [ -n "$squid_pid" ] && kill "$squid_pid" 2>/dev/null || true
          [ -n "$runtime" ] && rm -rf "$runtime" || true
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
        )

        while IFS= read -r p; do
          [ -n "$p" ] && args+=(--ro-bind "$p" "$p")
        done < ${closure}/store-paths

        ${lib.optionalString (devShellMode == "store") ''
          args+=(--ro-bind /nix/store /nix/store)
        ''}

        ${stagingScript}

        ${lib.optionalString (devShellMode == "closure") ''
          if [ -d "$stage" ]; then
            args+=(--ro-bind "$stage" "$stage")
            for p in "$stage"/*; do
              [ -e "$p" ] || continue
              target=$(readlink -f "$p" 2>/dev/null || true)
              case "$target" in
                /nix/store/*) args+=(--ro-bind "$target" "$target") ;;
              esac
            done
          fi
        ''}

        args+=(
          --ro-bind-try /etc/ssl/certs /etc/ssl/certs
          --ro-bind-try /etc/static/ssl /etc/static/ssl
          --ro-bind-try /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf
          --ro-bind-try /etc/pki /etc/pki
          --ro-bind-try /etc/hosts /etc/hosts
          --ro-bind-try /etc/passwd /etc/passwd
          --ro-bind-try /etc/group /etc/group
          --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf
          --ro-bind-try /etc/localtime /etc/localtime
          --ro-bind-try /etc/services /etc/services
          --ro-bind-try /etc/resolv.conf /etc/resolv.conf
          --ro-bind-try /usr/bin/env /usr/bin/env
          --ro-bind-try /bin/sh /bin/sh
          --ro-bind-try /run/current-system/sw/share/terminfo /run/current-system/sw/share/terminfo
          --ro-bind-try /dev/serial /dev/serial
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
          --setenv PATH ${dquote pathValue}
        )

        ${envArgs}

        ${proxySetup}

        args+=(--chdir "$workspace")

        status=0
        ${bwrap} "''${args[@]}" -- "''${app[@]}" "$@" || status=$?
        exit "$status"
      '';
    in
    pkgs.writeShellScriptBin outName script;
}
