{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.virtualisation;
in
{

  options.modules.virtualisation = {
    enable = lib.mkEnableOption "Enable virtualisation";
  };

  config = lib.mkIf cfg.enable {

    virtualisation.containers.enable = true;
    virtualisation = {
      docker = {
        enable = true;
      };
    };

  };
}
