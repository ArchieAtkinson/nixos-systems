{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.modules.gui;
in

{
  options.modules.gui = {
    enable = mkEnableOption "Enable Standard GUI Programs";
  };

  config = mkIf cfg.enable {
    services.displayManager.gdm.enable = true;
    services.displayManager.gdm.wayland = true;

    programs.niri.enable = true;
    programs.waybar.enable = true;
  };

}
