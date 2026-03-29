{
  config,
  pkgs,
  ...
}:

let
in
{

  sops.defaultSopsFile = ./resources/secrets.yaml;
  sops.age.keyFile = "/home/archie/.config/sops/age/keys.txt";
  sops.secrets.vpn_auth = { };
  sops.secrets.vpn_ca = { };

  nix.settings.experimental-features = "nix-command flakes";

  environment.variables.EDITOR = "hx";

  programs.command-not-found.enable = false;

  fonts.packages = with pkgs; [
    font-awesome
    nerd-fonts.jetbrains-mono
    jetbrains-mono
  ];

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  networking.networkmanager.enable = true;

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

  systemd.services."openvpn-tunnelbear" = {
    serviceConfig = {
      Restart = "always";
      RestartSec = "5";
      Wants = "network-online.target";
      After = [ "network-online.target" ];
    };
    wantedBy = [ "network-online.target" ];
  };
}
