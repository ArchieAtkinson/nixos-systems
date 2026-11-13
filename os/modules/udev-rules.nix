{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.udev-rules;

  # bwrap's user namespace drops supplementary groups, so dialout alone does
  # not survive into the sandbox. Give the real user an ACL on every USB and
  # serial node. This is a fixed single-user policy: all USB/serial devices
  # present at sandbox launch are visible; there is no hotplug.
  serialUsbRule = pkgs.writeTextFile {
    name = "opencode-serial-usb-udev";
    destination = "/etc/udev/rules.d/70-opencode-serial-usb.rules";
    text = ''
      SUBSYSTEM=="tty", KERNEL=="ttyUSB[0-9]*|ttyACM[0-9]*|ttyS[0-9]*|ttyAMA[0-9]*", MODE="0660", GROUP="dialout", TAG+="uaccess", RUN+="${pkgs.acl}/bin/setfacl -m u:archie:rw $env{DEVNAME}"
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0660", TAG+="uaccess", RUN+="${pkgs.acl}/bin/setfacl -m u:archie:rw $env{DEVNAME}"
    '';
  };
in

{
  options.modules.udev-rules = {
    probe-rs = mkEnableOption "Enable Probe RS udev rules";
    nrf-ppk = mkEnableOption "Enable nRF PPK udev rules";
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

    {
      services.udev.packages = [ serialUsbRule ];
    }
  ];
}
