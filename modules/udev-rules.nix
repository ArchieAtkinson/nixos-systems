{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.modules.udev-rules;
in

{
  options.modules.udev-rules = {
    probe-rs = mkEnableOption "Enable Probe RS udev rules";
    nrf-ppk = mkEnableOption "Enable nRF PPK udev rules";
  };

  config = mkMerge [
    (mkIf cfg.probe-rs {
      services.udev.extraRules = builtins.readFile ./resources/probe-rs.rules;
    })

    (mkIf cfg.nrf-ppk {
      services.udev.extraRules = ''
        # For nRF PPK
        SUBSYSTEM=="usb", ATTR{idVendor}=="1915", ATTR{idProduct}=="c00a" MODE="0666", GROUP="dialout"
      '';
    })
  ];
}
