{
  config,
  pkgs,
  hostname,
  ...
}:
{
  modules.common.enable = true;
  modules.gui.enable = true;
  modules.sops.enable = false;
  modules.user.archie = true;
  modules.audio.enable = true;
  modules.virtualisation.enable = true;
  modules.vpn.proton-vpn = true;
  modules.locale.GB = true;

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  networking.hostName = hostname;

  environment.systemPackages = with pkgs; [
    home-manager
  ];

  imports = [
    ./hardware-configuration.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.variables.NIXOS_OZONE_WL = "1";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # Pin to the release the system was installed with; check that release's notes before changing.
  system.stateVersion = "25.11";

}
