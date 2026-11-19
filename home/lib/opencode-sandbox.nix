# Builds the fixed-policy, policy-guarded OpenCode wrapper.
#
# The sandbox itself is the bubblewrap + Squid implementation in
# ./bwrap-sandbox.nix. There are no per-project wrappers or sandbox options.
{ pkgs, lib }:
let
  bwrapSandbox = import ./bwrap-sandbox.nix { inherit pkgs lib; };

  basePackages = with pkgs; [
    coreutils
    gitMinimal
    ripgrep
    fd
    gnused
    gnugrep
    findutils
    diffutils
    gawk
    jq
    less
    which
    curl
  ];

  defaultPackages = [
    pkgs.python3
    pkgs.uv
    pkgs.yq
  ];

  defaultAllowedDomains = {
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

    "wikipedia.org" = [
      "GET"
      "HEAD"
    ];
    "wikimedia.org" = [
      "GET"
      "HEAD"
    ];
    "wikidata.org" = [
      "GET"
      "HEAD"
    ];
    "wiktionary.org" = [
      "GET"
      "HEAD"
    ];
    "kagi.com" = [
      "GET"
      "HEAD"
    ];

    "arxiv.org" = [
      "GET"
      "HEAD"
    ];
    "export.arxiv.org" = [
      "GET"
      "HEAD"
    ];
    "doi.org" = [
      "GET"
      "HEAD"
    ];
    "ncbi.nlm.nih.gov" = [
      "GET"
      "HEAD"
    ];
    "europepmc.org" = [
      "GET"
      "HEAD"
    ];
    "biorxiv.org" = [
      "GET"
      "HEAD"
    ];
    "medrxiv.org" = [
      "GET"
      "HEAD"
    ];
    "nature.com" = [
      "GET"
      "HEAD"
    ];
    "science.org" = [
      "GET"
      "HEAD"
    ];
    "link.springer.com" = [
      "GET"
      "HEAD"
    ];
    "plos.org" = [
      "GET"
      "HEAD"
    ];
    "openreview.net" = [
      "GET"
      "HEAD"
    ];
    "semanticscholar.org" = [
      "GET"
      "HEAD"
    ];
    "zenodo.org" = [
      "GET"
      "HEAD"
    ];
    "openalex.org" = [
      "GET"
      "HEAD"
    ];
    "core.ac.uk" = [
      "GET"
      "HEAD"
    ];

    "ietf.org" = [
      "GET"
      "HEAD"
    ];
    "rfc-editor.org" = [
      "GET"
      "HEAD"
    ];
    "w3.org" = [
      "GET"
      "HEAD"
    ];
    "whatwg.org" = [
      "GET"
      "HEAD"
    ];
    "unicode.org" = [
      "GET"
      "HEAD"
    ];
    "iana.org" = [
      "GET"
      "HEAD"
    ];

    "developer.mozilla.org" = [
      "GET"
      "HEAD"
    ];
    "docs.python.org" = [
      "GET"
      "HEAD"
    ];
    "doc.rust-lang.org" = [
      "GET"
      "HEAD"
    ];
    "docs.rs" = [
      "GET"
      "HEAD"
    ];
    "go.dev" = [
      "GET"
      "HEAD"
    ];
    "pkg.go.dev" = [
      "GET"
      "HEAD"
    ];
    "man7.org" = [
      "GET"
      "HEAD"
    ];
    "docs.kernel.org" = [
      "GET"
      "HEAD"
    ];
    "readthedocs.io" = [
      "GET"
      "HEAD"
    ];
    "readthedocs.org" = [
      "GET"
      "HEAD"
    ];

    "stackoverflow.com" = [
      "GET"
      "HEAD"
    ];
    "stackexchange.com" = [
      "GET"
      "HEAD"
    ];
    "news.ycombinator.com" = [
      "GET"
      "HEAD"
    ];
    "lobste.rs" = [
      "GET"
      "HEAD"
    ];

    "web.archive.org" = [
      "GET"
      "HEAD"
    ];
    "archive.org" = [
      "GET"
      "HEAD"
    ];
    "gutenberg.org" = [
      "GET"
      "HEAD"
    ];
    "openlibrary.org" = [
      "GET"
      "HEAD"
    ];
    "data.gov" = [
      "GET"
      "HEAD"
    ];
    "who.int" = [
      "GET"
      "HEAD"
    ];
    "europa.eu" = [
      "GET"
      "HEAD"
    ];
    "worldbank.org" = [
      "GET"
      "HEAD"
    ];

    "reuters.com" = [
      "GET"
      "HEAD"
    ];
    "apnews.com" = [
      "GET"
      "HEAD"
    ];
    "bbc.co.uk" = [
      "GET"
      "HEAD"
    ];
    "npr.org" = [
      "GET"
      "HEAD"
    ];
    "theguardian.com" = [
      "GET"
      "HEAD"
    ];
  };

  # Keep the --norc --noprofile guarantee when PATH is overridden.
  bashNorc =
    pkgs.runCommand "opencode-bash-norc"
      {
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      }
      ''
        mkdir -p $out/bin
        makeBinaryWrapper ${pkgs.bashInteractive}/bin/bash $out/bin/bash \
          --add-flags "--norc" --add-flags "--noprofile"
        ln -s bash $out/bin/sh
      '';
in
{
  mkOpencodeSandbox =
    {
      pkg,
      policyFile,
      keyFile,
    }:
    let
      configDir = "$HOME/.config/opencode";
      dataDir = "$HOME/.local/share/opencode";
      stateDir = "$HOME/.local/state/opencode";
      cacheDir = "$HOME/.cache/opencode";

      allPackages = basePackages ++ defaultPackages;

      sandboxed = bwrapSandbox.mkSandbox {
        inherit pkg;
        allowedPackages = allPackages;
        pathPrefix = [ bashNorc ];

        rwDirs = [
          dataDir
          stateDir
          cacheDir
        ];

        roDirs = [ configDir ];

        # Expanded on the host at launch; secrets never enter the store.
        env = {
          OPENCODE_CONFIG_CONTENT = "$(cat ${policyFile})";
          OPENCODE_DISABLE_AUTOUPDATE = "1";
          OPENCODE_DISABLE_PROJECT_CONFIG = "1";
          UV_CACHE_DIR = "${cacheDir}/uv";
          GIT_CONFIG_NOSYSTEM = "1";
          GIT_CONFIG_GLOBAL = "/dev/null";
          GIT_AUTHOR_NAME = "$(git config --global user.name 2>/dev/null || true)";
          GIT_AUTHOR_EMAIL = "$(git config --global user.email 2>/dev/null || true)";
          GIT_COMMITTER_NAME = "$(git config --global user.name 2>/dev/null || true)";
          GIT_COMMITTER_EMAIL = "$(git config --global user.email 2>/dev/null || true)";
        };

        # Bound through a file and exported by the relay, so the key does not
        # appear in bwrap's argv (/proc/1/cmdline).
        secrets = {
          OPENCODE_API_KEY = keyFile;
        };

        allowedDomains = defaultAllowedDomains;
      };

      # Enforce managed policy + flags; isolation is the bwrap sandbox's job.
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
            printf 'opencode-sandbox: managed policy %s is missing; run home-manager switch first\n' ${policyFile} >&2
            exit 1
          fi
          if [ ! -f ${keyFile} ]; then
            printf 'opencode-sandbox: Go API key %s is missing; run os switch first\n' ${keyFile} >&2
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

          command_args=("$@")
          if [ "$standalone_command" = 1 ]; then
            command_args+=(--standalone)
          fi

          exec ${lib.getExe' sandboxed "opencode-sandboxed"} "''${command_args[@]}"
        '';
      };

      # expose only the sandboxed entrypoint (unwrapped via passthru.unwrapped).
      wrapped = pkgs.runCommand "opencode-sandboxed" { passthru.unwrapped = pkg; } ''
        mkdir -p $out/bin
        ln -s ${lib.getExe guarded} $out/bin/opencode
      '';
    in
    wrapped;
}
