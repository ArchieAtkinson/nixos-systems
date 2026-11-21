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

  # The PWF plugin handles lifecycle hooks; the skill carries the workflow text.
  planningWithFiles = pkgs.fetchFromGitHub {
    owner = "OthmanAdi";
    repo = "planning-with-files";
    rev = "7673790971ea36c88c3e9119bb2be105a29d7df0";
    hash = "sha256-C80eBzUTVKAtNCjPWmKfJA4yHOkFqGBzM8N4QEX6AtM=";
  };

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

    # PWF's skill is copied, not symlinked: the skill scanner does not follow
    # symlinked directories. The plugin itself is installed from the npm pin.
    home.activation.opencodePwfSkill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run rm -rf "${configDir}/skills/planning-with-files"
      run cp -r --no-preserve=mode \
        "${planningWithFiles}/.opencode/skills/planning-with-files" \
        "${configDir}/skills/planning-with-files"
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
      "opencode/commands/check.md".source = ./opencode-commands/check.md;
      "opencode/commands/handoff.md".source = ./opencode-commands/handoff.md;
    };

    home.packages = [ wrapped ];
  };
}
