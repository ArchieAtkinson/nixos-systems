# Builds the sandboxed, policy-guarded OpenCode wrapper.
#
# Shared by home/modules/opencode.nix (one global wrapper) and by per-project
# dev shells that want their project toolchain inside the sandbox. The
# filesystem view and the filtering proxy are the boundary; the managed policy
# only shapes behaviour.
#
# Callers pass the agent-sandbox library for their system as `agentSandbox`,
# so this file carries no flake inputs of its own:
#
#   (import ./lib/opencode-sandbox.nix {
#     inherit pkgs lib;
#     agentSandbox = inputs.agent-sandbox.lib.${pkgs.stdenv.hostPlatform.system};
#   }).mkOpencodeSandbox { pkg = pkgs.opencode; ... }
{ pkgs, lib, agentSandbox }:
let
  sbx = agentSandbox;

  # gitMinimal drops python/perl. curl stays: egress is filtered by the
  # proxy, so it is a useful fetch/download tool rather than a way out.
  basePackages = map (p: if (p.pname or "") == "git" then pkgs.gitMinimal else p) sbx.commonTools;

  # Lean baseline beyond commonTools: a scripting runtime plus structured-data
  # tooling. Project-specific toolchains belong in extraPackages (normally via
  # a per-project wrapper) so the global view stays small.
  defaultPackages = [
    pkgs.python3
    pkgs.uv
    pkgs.yq
  ];

  # The curated read-only egress allowlist, shared by the global module and
  # per-project wrappers so a project does not silently start with no network.
  # Values are "*" (all methods) or a list of HTTP methods; domains match by
  # suffix, so "wikipedia.org" covers every subdomain.
  defaultAllowedDomains = {
    # provider + search tooling.
    "opencode.ai" = "*";
    "mcp.exa.ai" = "*";
    "search.parallel.ai" = "*";
    "github.com" = [
      "GET"
      "POST"
    ];
    "githubusercontent.com" = [ "GET" ];
    "registry.npmjs.org" = [ "GET" ];
    "pypi.org" = [ "GET" ];
    "files.pythonhosted.org" = [ "GET" ];
    "crates.io" = [ "GET" ];
    "cache.nixos.org" = [ "GET" ];

    # reference.
    "wikipedia.org" = [ "GET" "HEAD" ];
    "wikimedia.org" = [ "GET" "HEAD" ];
    "wikidata.org" = [ "GET" "HEAD" ];
    "wiktionary.org" = [ "GET" "HEAD" ];
    "kagi.com" = [ "GET" "HEAD" ];

    # academic reading.
    "arxiv.org" = [ "GET" "HEAD" ];
    "export.arxiv.org" = [ "GET" "HEAD" ];
    "doi.org" = [ "GET" "HEAD" ];
    "ncbi.nlm.nih.gov" = [ "GET" "HEAD" ];
    "europepmc.org" = [ "GET" "HEAD" ];
    "biorxiv.org" = [ "GET" "HEAD" ];
    "medrxiv.org" = [ "GET" "HEAD" ];
    "nature.com" = [ "GET" "HEAD" ];
    "science.org" = [ "GET" "HEAD" ];
    "link.springer.com" = [ "GET" "HEAD" ];
    "plos.org" = [ "GET" "HEAD" ];
    "openreview.net" = [ "GET" "HEAD" ];
    "semanticscholar.org" = [ "GET" "HEAD" ];
    "zenodo.org" = [ "GET" "HEAD" ];
    "openalex.org" = [ "GET" "HEAD" ];
    "core.ac.uk" = [ "GET" "HEAD" ];

    # standards.
    "ietf.org" = [ "GET" "HEAD" ];
    "rfc-editor.org" = [ "GET" "HEAD" ];
    "w3.org" = [ "GET" "HEAD" ];
    "whatwg.org" = [ "GET" "HEAD" ];
    "unicode.org" = [ "GET" "HEAD" ];
    "iana.org" = [ "GET" "HEAD" ];

    # language / library docs.
    "developer.mozilla.org" = [ "GET" "HEAD" ];
    "docs.python.org" = [ "GET" "HEAD" ];
    "doc.rust-lang.org" = [ "GET" "HEAD" ];
    "docs.rs" = [ "GET" "HEAD" ];
    "go.dev" = [ "GET" "HEAD" ];
    "pkg.go.dev" = [ "GET" "HEAD" ];
    "man7.org" = [ "GET" "HEAD" ];
    "docs.kernel.org" = [ "GET" "HEAD" ];
    "readthedocs.io" = [ "GET" "HEAD" ];
    "readthedocs.org" = [ "GET" "HEAD" ];

    # community.
    "stackoverflow.com" = [ "GET" "HEAD" ];
    "stackexchange.com" = [ "GET" "HEAD" ];
    "news.ycombinator.com" = [ "GET" "HEAD" ];
    "lobste.rs" = [ "GET" "HEAD" ];

    # archives and public data.
    "web.archive.org" = [ "GET" "HEAD" ];
    "archive.org" = [ "GET" "HEAD" ];
    "gutenberg.org" = [ "GET" "HEAD" ];
    "openlibrary.org" = [ "GET" "HEAD" ];
    "data.gov" = [ "GET" "HEAD" ];
    "who.int" = [ "GET" "HEAD" ];
    "europa.eu" = [ "GET" "HEAD" ];
    "worldbank.org" = [ "GET" "HEAD" ];

    # news.
    "reuters.com" = [ "GET" "HEAD" ];
    "apnews.com" = [ "GET" "HEAD" ];
    "bbc.co.uk" = [ "GET" "HEAD" ];
    "npr.org" = [ "GET" "HEAD" ];
    "theguardian.com" = [ "GET" "HEAD" ];
  };

  # Reduced-nix "closure" mode staging directory. The guarded wrapper fills it
  # with symlinks to the closure of the store paths on PATH; the launcher
  # follows those into the store and binds them read-only. It lives beside the
  # OpenCode cache (not inside a declared rw dir) to avoid a nested bind.
  closureStageDir = "$HOME/.cache/opencode-devshell";

  # Mirrors agent-sandbox's implicit bash wrapper so that overriding PATH in
  # reduced-nix mode does not lose the --norc --noprofile guarantee.
  bashNorc = pkgs.runCommand "opencode-bash-norc" {
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
  } ''
    mkdir -p $out/bin
    makeBinaryWrapper ${pkgs.bashInteractive}/bin/bash $out/bin/bash \
      --add-flags "--norc" --add-flags "--noprofile"
    ln -s bash $out/bin/sh
  '';
in
{
  inherit defaultAllowedDomains;

  mkOpencodeSandbox =
    {
      pkg,
      # Binary to run inside `pkg`. The name of the produced command is always
      # `opencode`; this only selects the upstream entrypoint.
      pkgBinName ? "opencode",
      outName ? "opencode-sandboxed",
      policyFile ? "/etc/opencode/opencode.json",
      goKeyFile ? "/run/secrets/opencode_go_key",
      configDir ? "$HOME/.config/opencode",
      dataDir ? "$HOME/.local/share/opencode",
      stateDir ? "$HOME/.local/state/opencode",
      cacheDir ? "$HOME/.cache/opencode",
      extraPackages ? [ ],
      extraReadOnlyDirs ? [ ],
      # Reduced-nix mode:
      #   "off"   - only the closure of allowedPackages is mounted (default).
      #   "store" - the whole Nix store is mounted read-only and the launching
      #             shell's PATH is inherited, so a dev shell's tools are
      #             available to the agent. There is no daemon, so nix cannot
      #             build or fetch inside the sandbox.
      devShellMode ? "off",
      allowedDomains ? defaultAllowedDomains,
      extraDomains ? { },
      internet ? "restricted",
      disableProjectConfig ? true,
    }:
    let
      allPackages = basePackages ++ defaultPackages ++ extraPackages;
      # bashNorc is bound so the reduced-nix PATH override resolves in closure
      # mode too (where the store is not wholly mounted).
      bindPackages = allPackages ++ [ bashNorc ];

      # Reduced-nix "closure" mode: stage symlinks to the closure of the store
      # paths on PATH before launch. The launcher follows them into the store
      # and binds only those paths read-only, so PATH entries resolve without
      # exposing the whole store.
      stagingScript = lib.optionalString (devShellMode == "closure") ''
        stage=${closureStageDir}
        new="$stage.new.$$"
        rm -rf "$new"
        mkdir -p "$new"

        printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r entry; do
          case "$entry" in
            /nix/store/*/bin) dirname "$entry" ;;
          esac
        done | sort -u > "$new/.roots" || true

        # Prefer the system profile's nix-store; fall back to PATH only if it
        # is absent, so a dev shell cannot substitute the binary we execute.
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

        # Swap the complete staging dir into place so a concurrent launch never
        # scans a half-built set.
        rm -rf "$stage"
        mv -T "$new" "$stage"
      '';

      sandboxed = sbx.mkSandbox (
        {
          inherit pkg outName;
          binName = pkgBinName;
          allowedPackages = bindPackages;

          rwDirs = [
            dataDir
            stateDir
            cacheDir
          ];

          # block writes to global agents/commands/skills/plugins; extra dirs
          # are read-only context (dotfiles, reference trees). In reduced-nix
          # mode the whole store is read-only so inherited PATH entries resolve
          # (overlays bwrap's --tmpfs /nix/store; no daemon socket is exposed).
          roDirs =
            [ configDir ]
            ++ extraReadOnlyDirs
            ++ lib.optional (devShellMode == "store") "/nix/store"
            ++ lib.optional (devShellMode == "closure") closureStageDir;

          # expanded on host at launch; secrets never enter the store.
          env =
            {
              OPENCODE_API_KEY = "$(cat ${goKeyFile})";
              OPENCODE_CONFIG_CONTENT = "$(cat ${policyFile})";
              OPENCODE_DISABLE_AUTOUPDATE = "1";
              # keep uv's downloads inside a persisted rw dir.
              UV_CACHE_DIR = "${cacheDir}/uv";
              # loopback must bypass the proxy in restricted mode.
              NO_PROXY = "localhost,127.0.0.1,::1";
              no_proxy = "localhost,127.0.0.1,::1";
              # ignore sandbox-writable git config; identity from host config.
              GIT_CONFIG_NOSYSTEM = "1";
              GIT_CONFIG_GLOBAL = "/dev/null";
              GIT_AUTHOR_NAME = "$(git config --global user.name 2>/dev/null || true)";
              GIT_AUTHOR_EMAIL = "$(git config --global user.email 2>/dev/null || true)";
              GIT_COMMITTER_NAME = "$(git config --global user.name 2>/dev/null || true)";
              GIT_COMMITTER_EMAIL = "$(git config --global user.email 2>/dev/null || true)";
            }
            # Set only when disabling: an unset flag and a truthy flag are both
            # treated as "disabled off/on" without relying on a "0" parse.
            // lib.optionalAttrs disableProjectConfig {
              OPENCODE_DISABLE_PROJECT_CONFIG = "1";
            }
            # Declared env is applied after the launcher's computed PATH, so
            # this wins; $PATH expands in the shell that launched the wrapper.
            # Order: wrapped bash, then the launch shell (dev-shell tools take
            # precedence), then the sandbox baseline as a fallback.
            // lib.optionalAttrs (devShellMode != "off") {
              PATH = "${lib.makeBinPath [ bashNorc ]}:$PATH:${lib.makeBinPath allPackages}";
            };
        }
        // lib.optionalAttrs (internet == "restricted") {
          allowedDomains = allowedDomains // extraDomains;
        }
      );

      # enforce managed policy + flags; isolation is agent-sandbox's job.
      guarded = pkgs.writeShellApplication {
        name = "opencode";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.jq
        ];
        text = ''
          # fail closed if policy or key is missing.
          if [ ! -f ${policyFile} ]; then
            printf 'opencode-sandbox: managed policy %s is missing; run os switch first\n' ${policyFile} >&2
            exit 1
          fi
          if [ ! -f ${goKeyFile} ]; then
            printf 'opencode-sandbox: Go API key %s is missing; run os switch first\n' ${goKeyFile} >&2
            exit 1
          fi

          # fail closed on invalid JSON or missing managed rules.
          if ! jq -e . ${policyFile} >/dev/null 2>&1; then
            printf 'opencode-sandbox: managed policy %s is not valid JSON; refusing to launch\n' ${policyFile} >&2
            exit 1
          fi
          if ! grep -q 'provider\.use' ${policyFile} \
            || ! grep -q 'opencode-go' ${policyFile} \
            || ! grep -q 'webfetch' ${policyFile}; then
            printf 'opencode-sandbox: managed policy %s lacks the expected rules; refusing to launch\n' ${policyFile} >&2
            exit 1
          fi

          # reject forbidden flags.
          hostname_value=""
          expect_hostname=0
          for arg in "$@"; do
            if [ "$expect_hostname" = 1 ]; then
              hostname_value="$arg"
              expect_hostname=0
              continue
            fi
            case "$arg" in
              --auto|--auto=*|--yolo|--yolo=*|--dangerously-skip-permissions)
                printf 'opencode-sandbox: %s is blocked by the managed OpenCode policy\n' "$arg" >&2
                exit 1
                ;;
              --hostname)
                expect_hostname=1
                ;;
              --hostname=*)
                hostname_value="''${arg#--hostname=}"
                ;;
            esac
          done

          case "$hostname_value" in
            ""|127.0.0.1|localhost|::1|\[::1\])
              ;;
            *)
              printf 'opencode-sandbox: --hostname %s is blocked by the managed OpenCode policy (loopback only)\n' "$hostname_value" >&2
              exit 1
              ;;
          esac

          # service/reload manage a host service, invisible here.
          if [ "$#" -gt 0 ]; then
            case "$1" in
              service|reload)
                printf 'opencode-sandbox: "%s" manages the host background service and is not supported in the sandbox;\n' "$1" >&2
                printf 'opencode-sandbox: use "opencode serve" or run the TUI instead\n' >&2
                exit 1
                ;;
            esac
          fi

          # keep the background server inside the sandbox.
          standalone_command=1
          if [ "$#" -gt 0 ]; then
            case "$1" in
              upgrade|uninstall|acp|api|debug|auth|mcp|plugin|serve|pair)
                standalone_command=0
                ;;
            esac
          fi

          ${stagingScript}

          command_args=("$@")
          if [ "$standalone_command" = 1 ]; then
            command_args+=(--standalone)
          fi

          exec ${lib.getExe' sandboxed outName} "''${command_args[@]}"
        '';
      };

  # expose only the sandboxed entrypoint (unwrapped via passthru.unwrapped).
  wrapped = pkgs.runCommand outName { passthru.unwrapped = pkg; } ''
    mkdir -p $out/bin
    ln -s ${lib.getExe guarded} $out/bin/opencode
  '';
    in
    wrapped;
}
