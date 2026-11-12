{
  config,
  pkgs,
  hostname,
  ...
}:
let
in
{
  modules.common.enable = true;
  modules.gui.enable = true;
  modules.xremap.enable = true;
  modules.sops.enable = true;
  modules.user.archie = true;
  modules.audio.enable = true;
  modules.virtualisation.enable = true;
  modules.vpn.proton-vpn = true;
  modules.locale.GB = true;
  modules.syncthing.enable = true;
  modules.opencode.enable = true;

  modules.udev-rules.nrf-ppk = true;
  modules.udev-rules.probe-rs = true;
  modules.rtl28xx.enable = true;

  networking.hostName = hostname;

  services.librechat = {
    enable = true;
    enableLocalDB = true;
    openFirewall = false;
    credentialsFile = "/etc/librechat.env";
    settings = {
      cache = true;
      endpoints = {
        custom = [
          {
            apiKey = "\${OPENROUTER_KEY}";
            baseURL = "https://openrouter.ai/api/v1";
            dropParams = [
              "stop"
            ];
            modelDisplayLabel = "OpenRouter";
            models = {
              default = [
                "deepseek/deepseek-v4-flash"
              ];
              fetch = true;
            };
            name = "OpenRouter";
            titleConvo = true;
            titleModule = "deepseek/deepseek-v4-flash";
          }
        ];
      };
      interface = {
        privacyPolicy = {
          externalUrl = "https://librechat.ai/privacy-policy";
          openNewTab = true;
        };

        contextUsage = true;
        contextCost = true;
        currency = {
          code = "USD";
          rate = 1;
        };
      };
      version = "1.3.13";
    };
  };

  services.mongodb = {
    enable = true;
    package = pkgs.mongodb-ce;
  };

  networking.firewall.allowedTCPPorts = [ 3080 ];
  networking.firewall.allowedUDPPorts = [ 4242 ]; # lan-mouse

  environment.systemPackages = with pkgs; [
    home-manager
  ];

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.variables.NIXOS_OZONE_WL = "1";

  # Pin to the release the system was installed with; check that release's notes before changing.
  system.stateVersion = "24.11";

}
