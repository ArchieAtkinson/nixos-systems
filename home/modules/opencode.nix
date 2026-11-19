{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;

  # postInstall (completions) fails upstream.
  upstream = inputs.opencode.packages.${system}.opencode.overrideAttrs (_: {
    postInstall = "";
  });

  opencodeSandbox = import ../lib/opencode-sandbox.nix {
    inherit pkgs lib;
  };

  policy = import ../lib/opencode-policy.nix { inherit lib; };

  configDir = "${config.home.homeDirectory}/.config/opencode";
  dataDir = "${config.home.homeDirectory}/.local/share/opencode";
  stateDir = "${config.home.homeDirectory}/.local/state/opencode";
  cacheDir = "${config.home.homeDirectory}/.cache/opencode";

  # The key is still delivered by the OS-level sops module.
  policyFile = "${configDir}/opencode.json";
  keyFile = "/run/secrets/opencode_go_key";

  wrapped = opencodeSandbox.mkOpencodeSandbox {
    pkg = upstream;
    inherit policyFile keyFile;
  };
in
{
  options.modules.opencode = {
    enable = lib.mkEnableOption "sandboxed OpenCode v2 environment";
  };

  config = lib.mkIf config.modules.opencode.enable {
    # declared binds must exist before launch.
    home.activation.opencodeSandboxDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${
        lib.escapeShellArgs [
          configDir
          dataDir
          cacheDir
          stateDir
        ]
      }
    '';

    # advisory only; the sandbox is the boundary.
    xdg.configFile = {
      "opencode/opencode.json" = {
        text = builtins.toJSON policy;
        force = true;
      };

      "opencode/AGENTS.md".source = ./opencode-AGENTS.md;

      # task playbooks; the model loads one when a task matches.
      "opencode/skills/code-review/SKILL.md".source = ./opencode-skills/code-review/SKILL.md;
      "opencode/skills/bug-investigation/SKILL.md".source = ./opencode-skills/bug-investigation/SKILL.md;
      "opencode/skills/nixos-change/SKILL.md".source = ./opencode-skills/nixos-change/SKILL.md;
      "opencode/skills/embedded-debug/SKILL.md".source = ./opencode-skills/embedded-debug/SKILL.md;

      # reusable invocations for the common workflows.
      "opencode/commands/review.md".source = ./opencode-commands/review.md;
      "opencode/commands/investigate.md".source = ./opencode-commands/investigate.md;
      "opencode/commands/nixos.md".source = ./opencode-commands/nixos.md;
    };

    home.packages = [ wrapped ];
  };
}
