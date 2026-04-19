{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:

let
  cfg = config.modules.syncthing;
in
{

  options.modules.syncthing = {
    enable = lib.mkEnableOption "Enable Syncthing";
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = "archie";
      dataDir = "/home/archie/.local/share/syncthing";
      configDir = "/home/archie/.config/syncthing";
      key = config.sops.secrets."syncthing_key_${hostname}".path;
      cert = config.sops.secrets."syncthing_cert_${hostname}".path;
      settings = {
        devices = {
          "xps" = {
            id = "VTFCUO2-DK47Z33-26NK3LQ-OTESVKJ-JBJCYJ6-7XR3QXU-CUSGOPT-764SPQC";
          };
        };
        folders = {
          "Notes" = {
            path = "/home/archie/notes";
            devices = [
              "xps"
            ];
          };
        };
      };
    };
  };
}
