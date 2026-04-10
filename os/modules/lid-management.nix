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
    services.logind.settings.Login.HandleLidSwitch = "sleep";
    services.logind.settings.Login.HandleLidSwitchExternalPower = "sleep";
    services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

    services.upower.ignoreLid = true;
  };
}
