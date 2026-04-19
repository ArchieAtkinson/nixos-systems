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
    tunnel-bear = lib.mkEnableOption "Enable Tunnel Bear VPN";
    proton-vpn = lib.mkEnableOption "Enable ProtonVPN";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.tunnel-bear {
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
    })

    (lib.mkIf cfg.proton-vpn {
      environment.systemPackages = with pkgs; [
        wireguard-tools
        protonvpn-gui
      ];
    })
  ];
}
