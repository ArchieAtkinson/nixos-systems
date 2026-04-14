{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.fw-dev;
in
{

  options.modules.fw-dev = {
    enable = lib.mkEnableOption "Enable Firmware Dev Software";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      kicad-unstable
      nrfconnect
      nrf-udev
      sdrpp
      segger-jlink
      minicom
      popsicle
    ];

    nixpkgs.config.permittedInsecurePackages = [
      "segger-jlink-qt4-874"
    ];

    nixpkgs.config.segger-jlink.acceptLicense = true;

  };
}
