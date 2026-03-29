{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.modules.rtl28xx;
in

{
  options.modules.rtl28xx = {
    enable = mkEnableOption "Enable ";
  };

  config = mkIf cfg.enable {
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", MODE="0666", GROUP="plugdev"
    '';

    boot.blacklistedKernelModules = [
      "dvb_usb_rtl28xxu"
      "rtl2832_sdr"
    ];
  };

}
