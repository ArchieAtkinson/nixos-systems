{
  config,
  lib,
  pkgs,
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
    serial-tty = mkEnableOption "Make serial tty devices accessible to the OpenCode sandbox";
  };

  config = mkMerge [
    (mkIf cfg.probe-rs {
      services.udev.packages = [ pkgs.probe-rs-tools ];
    })

    (mkIf cfg.nrf-ppk {
      services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="1915", ATTR{idProduct}=="c00a" MODE="0666", GROUP="dialout"
      '';
    })

    # bwrap's user namespace drops supplementary groups, so a tty node owned
    # root:dialout is not reachable even though the launching user is in
    # dialout. Widen the serial nodes instead of not unsharing the user.
    (mkIf cfg.serial-tty {
      services.udev.extraRules = ''
        KERNEL=="ttyUSB[0-9]*", MODE="0666"
        KERNEL=="ttyACM[0-9]*", MODE="0666"
        KERNEL=="ttyS[0-9]*", MODE="0666"
        KERNEL=="ttyAMA[0-9]*", MODE="0666"
      '';
    })
  ];
}
