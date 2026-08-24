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
    enableLocalDB = true; # runs a local MongoDB automatically
    openFirewall = false; # opens port 3080 (default)
    # port = 3080;
    credentialsFile = "/etc/librechat.env"; # path to your secrets (see below)
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
    package = pkgs.mongodb-ce; # ← this solves the slow build
  };

  networking.firewall.allowedTCPPorts = [ 3080 ];

  environment.systemPackages = with pkgs; [
    home-manager
  ];

  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.variables.NIXOS_OZONE_WL = "1";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
