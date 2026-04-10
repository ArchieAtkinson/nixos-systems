{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.vpn;
in
{

  options.modules.vpn = {
    enable = lib.mkEnableOption "Enable VPN";
  };

  config = lib.mkIf cfg.enable {
    services.openvpn.servers = {
      tunnelbear = {
        config = ''
          client
          remote ie.lazerpenguin.com 443
          dev tun0
          proto udp
          nobind
          remote-cert-tls server
          persist-key
          persist-tun
          reneg-sec 0
          dhcp-option DNS 8.8.8.8
          dhcp-option DNS 8.8.4.4
          redirect-gateway
          verb 5
          auth-user-pass ${config.sops.secrets.vpn_auth.path}
          ca ${config.sops.secrets.vpn_ca.path}
          data-ciphers AES-256-CBC
          auth SHA256
        '';
      };
    };

    environment.systemPackages = with pkgs; [
      wireguard-tools
      protonvpn-gui
    ];
  };
}
