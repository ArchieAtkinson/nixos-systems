{
  config,
  pkgs,
  hostname,
  ...
}:
let

in
{
  networking.hostName = hostname; # Define your hostname.

  imports = [
    ./hardware-configuration.nix
  ];

  modules.udev-rules.nrf-ppk = true;
  modules.udev-rules.probe-rs = true;
  modules.rtl28xx.enable = true;
  modules.gui.enable = true;
  modules.common.enable = true;
  modules.xremap.enable = true;
  modules.sops.enable = true;
  modules.user.archie = true;
  modules.audio.enable = true;
  modules.virtualisation.enable = true;
  modules.vpn.enable = true;
  modules.locale.GB = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  programs.fish.enable = true;

  environment.variables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    home-manager
    glib # For gsettings
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
