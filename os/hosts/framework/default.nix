{
  config,
  pkgs,
  hostname,
  inputs,
  ...
}:
{

  programs.ydotool = {
    enable = true;
  };

  users.users.archie.extraGroups = [ "input" ];

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

  networking.firewall.allowedUDPPorts = [ 4242 ]; # lan-mouse

  programs.steam = {
    enable = true;
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  networking.hostName = hostname;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.gnome-session ];
  };

  environment.systemPackages = with pkgs; [
    home-manager
    gnome-network-displays
    glib-networking # TLS backend for GIO
    gsettings-desktop-schemas
    framework-tool
  ];

  programs.dconf.enable = true;

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.variables.NIXOS_OZONE_WL = "1";

  # Pin to the release the system was installed with; check that release's notes before changing.
  system.stateVersion = "25.11";

}
