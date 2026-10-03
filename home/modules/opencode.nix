{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.opencode;
  system = pkgs.stdenv.hostPlatform.system;

  # postInstall (completions) fails upstream.
  upstream = inputs.opencode.packages.${system}.opencode.overrideAttrs (_: {
    postInstall = "";
  });

  # bubblewrap/Linux, sandbox-exec/macOS; owns fs, packages, network.
  sbx = inputs.agent-sandbox.lib.${system};

  sandboxed = sbx.mkSandbox ({
    pkg = cfg.package;
    binName = "opencode";
    outName = "opencode-sandboxed";
    # gitMinimal drops python/perl; drop curl.
    allowedPackages =
      map (p: if (p.pname or "") == "git" then pkgs.gitMinimal else p)
        (builtins.filter (p: (p.pname or "") != "curl") sbx.commonTools);

    rwDirs = [
      "${cfg.dataDir}"
      "${cfg.stateDir}"
      "${cfg.cacheDir}"
    ];

    # block writes to global agents/commands/skills/plugins.
    roDirs = [ "${cfg.configDir}" ];

    # expanded on host at launch; secrets never enter the store.
    env = {
      OPENCODE_API_KEY = "$(cat ${cfg.goKeyFile})";
      OPENCODE_CONFIG_CONTENT = "$(cat ${cfg.policyFile})";
      OPENCODE_DISABLE_AUTOUPDATE = "1";
      # no project config / AGENTS.md discovery.
      OPENCODE_DISABLE_PROJECT_CONFIG = "1";
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
    };
  } // lib.optionalAttrs (cfg.internet == "restricted") { inherit (cfg) allowedDomains; });

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
      if [ ! -f ${cfg.policyFile} ]; then
        printf 'opencode-sandbox: managed policy %s is missing; run os switch first\n' ${cfg.policyFile} >&2
        exit 1
      fi
      if [ ! -f ${cfg.goKeyFile} ]; then
        printf 'opencode-sandbox: Go API key %s is missing; run os switch first\n' ${cfg.goKeyFile} >&2
        exit 1
      fi

      # fail closed on invalid JSON or missing managed rules.
      if ! jq -e . ${cfg.policyFile} >/dev/null 2>&1; then
        printf 'opencode-sandbox: managed policy %s is not valid JSON; refusing to launch\n' ${cfg.policyFile} >&2
        exit 1
      fi
      if ! grep -q 'provider\.use' ${cfg.policyFile} \
        || ! grep -q 'opencode-go' ${cfg.policyFile} \
        || ! grep -q 'webfetch' ${cfg.policyFile}; then
        printf 'opencode-sandbox: managed policy %s lacks the expected rules; refusing to launch\n' ${cfg.policyFile} >&2
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
  wrapped = pkgs.runCommand "opencode-sandboxed" { passthru.unwrapped = cfg.package; } ''
    mkdir -p $out/bin
    ln -s ${lib.getExe guarded} $out/bin/opencode
  '';
in
{
  options.modules.opencode = {
    enable = lib.mkEnableOption "sandboxed OpenCode v2 environment";

    package = lib.mkOption {
      type = lib.types.package;
      default = upstream;
      defaultText = lib.literalExpression "inputs.opencode.packages.\${system}.opencode";
      description = "OpenCode package to run inside the agent-sandbox.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/opencode";
      description = "OpenCode config directory, mounted read-only.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/opencode";
      description = "Persistent OpenCode data directory, mounted read-write.";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.cache/opencode";
      description = "OpenCode cache directory, mounted read-write.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/state/opencode";
      description = "OpenCode state directory, mounted read-write.";
    };

    goKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/opencode_go_key";
      description = "sops-managed OpenCode Go API key, exported as OPENCODE_API_KEY.";
    };

    policyFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/opencode/opencode.json";
      description = "Root-owned managed policy injected as OPENCODE_CONFIG_CONTENT.";
    };

    internet = lib.mkOption {
      type = lib.types.enum [
        "restricted"
        "open"
      ];
      default = "restricted";
      description = ''
        restricted: only allowedDomains may be reached. open: unrestricted egress.
      '';
    };

    allowedDomains = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.either lib.types.str (lib.types.listOf lib.types.str)
      );
      default = {
        "opencode.ai" = "*";
        "mcp.exa.ai" = "*";
        "search.parallel.ai" = "*";
        "github.com" = [ "GET" "POST" ];
        "githubusercontent.com" = [ "GET" ];
        "registry.npmjs.org" = [ "GET" ];
        "pypi.org" = [ "GET" ];
        "files.pythonhosted.org" = [ "GET" ];
        "crates.io" = [ "GET" ];
        "cache.nixos.org" = [ "GET" ];
      };
      description = ''
        Egress allowlist when internet = "restricted". Value is "*" (all
        methods) or a list of HTTP methods. Domains match by suffix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # declared binds must exist before launch.
    home.activation.opencodeSandboxDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArgs [
        cfg.configDir
        cfg.dataDir
        cfg.cacheDir
        cfg.stateDir
      ]}
    '';

    # advisory only; the sandbox is the boundary.
    xdg.configFile."opencode/AGENTS.md".source = ./opencode-AGENTS.md;

    home.packages = [ wrapped ];
  };
}
