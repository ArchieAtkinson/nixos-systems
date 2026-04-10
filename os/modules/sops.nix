{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.sops;
in
{

  options.modules.sops = {
    enable = lib.mkEnableOption "Enable sops";
  };

  config = lib.mkIf cfg.enable {
    sops.defaultSopsFile = ./resources/secrets.yaml;
    sops.age.keyFile = "/home/archie/.config/sops/age/keys.txt";
    sops.secrets.vpn_auth = { };
    sops.secrets.vpn_ca = { };
  };
}
