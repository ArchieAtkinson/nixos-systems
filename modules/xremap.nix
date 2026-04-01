{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.xremap;
in
{

  options.modules.xremap = {
    enable = lib.mkEnableOption "Enable xremap services";
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      xremap
    ];

    # Couldn't get sudo-less xremap to work
    systemd.services.xremap-system = {
      description = "System xremap service";
      enable = true;
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.xremap}/bin/xremap ${./resources/xremap.yml}";
      };
    };

  };
}
