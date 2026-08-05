{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.modules.lid-management;
in

{
  options.modules.lid-management = {
    enable = mkEnableOption "Enable Laptop Lid Management";
  };

  config = mkIf cfg.enable {
    services.logind.settings.Login.HandleLidSwitch = "hibernate";
    services.logind.settings.Login.HandleLidSwitchExternalPower = "suspend-then-hibernate";
    services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

    services.upower.ignoreLid = true;
  };
}
