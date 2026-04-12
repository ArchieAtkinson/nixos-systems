{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.core-gui;
in
{

  options.modules.core-gui = {
    enable = lib.mkEnableOption "Enable Core GUI Programs";
  };

  config = lib.mkIf cfg.enable {
    programs.firefox.enable = true;

    home.packages = with pkgs; [
      kickoff # App Launcher
      hyprlock
      ghostty
      swayidle
    ];
  };
}
