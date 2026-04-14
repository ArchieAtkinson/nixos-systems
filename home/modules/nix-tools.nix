{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.nix-tools;
in
{

  options.modules.nix-tools = {
    enable = lib.mkEnableOption "Enable Nix Tooling";
  };

  config = lib.mkIf cfg.enable {

    home.packages = with pkgs; [
      nixfmt
      nixd
    ];

  };
}
