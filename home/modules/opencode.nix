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

  # Shared builder: the global wrapper and per-project dev shells use it.
  opencodeSandbox = import ../lib/opencode-sandbox.nix {
    inherit pkgs lib;
    agentSandbox = inputs.agent-sandbox.lib.${system};
  };
  mkOpencodeSandbox = opencodeSandbox.mkOpencodeSandbox;

  wrapped = mkOpencodeSandbox {
    pkg = cfg.package;
    policyFile = cfg.policyFile;
    goKeyFile = cfg.goKeyFile;
    configDir = cfg.configDir;
    dataDir = cfg.dataDir;
    stateDir = cfg.stateDir;
    cacheDir = cfg.cacheDir;
    extraPackages = cfg.extraPackages;
    extraReadOnlyDirs = cfg.extraReadOnlyDirs;
    devShellMode = cfg.devShellMode;
    allowedDomains = cfg.allowedDomains;
    extraDomains = cfg.extraDomains;
    internet = cfg.internet;
  };
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
      default = opencodeSandbox.defaultAllowedDomains;
      defaultText = lib.literalMD "the curated default allowlist";
      description = ''
        Egress allowlist when internet = "restricted". Value is "*" (all
        methods) or a list of HTTP methods. Domains match by suffix; anything
        not listed is blocked by the proxy. Defaults to the curated read-only
        set shared with per-project wrappers.
      '';
    };

    extraDomains = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.either lib.types.str (lib.types.listOf lib.types.str)
      );
      default = { };
      description = ''
        Extra egress allowlist entries merged over allowedDomains (same shape
        and matching rules). Keys here win over allowedDomains.
      '';
      example = lib.literalExpression ''
        {
          "docs.rs" = [ "GET" ];
        }
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Packages added to the sandbox on top of the lean baseline
        (agent-sandbox commonTools with curl, plus python3, uv and yq).
        Prefer a per-project wrapper for project toolchains.
      '';
      example = lib.literalExpression "[ pkgs.duckdb pkgs.miller ]";
    };

    extraReadOnlyDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra host directories mounted read-only, for dotfiles or reference
        context. Paths expand at launch ($VAR, ${"~"}); a missing path refuses
        the launch.
      '';
      example = lib.literalExpression ''[ "$HOME/dotfiles" "$HOME/notes" ]'';
    };

    devShellMode = lib.mkOption {
      type = lib.types.enum [
        "off"
        "store"
        "closure"
      ];
      default = "off";
      description = ''
        Reduced-nix mode. "off" mounts only the sandbox package closure.
        "store" additionally mounts the whole Nix store read-only and inherits
        the launching shell's PATH, so tools from a `nix develop` shell are
        available. "closure" is the same but binds only the closure of the
        store paths on PATH, via a host-side staging directory. None expose
        the nix daemon, so `nix develop`/`nix build` still do not run inside.
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
