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

  wrapped = opencodeSandbox.mkOpencodeSandbox {
    pkg = upstream;
  };

  configDir = "${config.home.homeDirectory}/.config/opencode";
  dataDir = "${config.home.homeDirectory}/.local/share/opencode";
  stateDir = "${config.home.homeDirectory}/.local/state/opencode";
  cacheDir = "${config.home.homeDirectory}/.cache/opencode";
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
    xdg.configFile."opencode/AGENTS.md".source = ./opencode-AGENTS.md;

    home.packages = [ wrapped ];
  };
}
