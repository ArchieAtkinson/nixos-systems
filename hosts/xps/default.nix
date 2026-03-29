{
  config,
  pkgs,
  hostname,
  ...
}:
let

in
{
  imports = [
    ./hardware-configuration.nix
  ];

  modules.udev-rules.nrf-ppk = true;
  modules.udev-rules.probe-rs = true;
  modules.rtl28xx.enable = true;

  services.fwupd.enable = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = hostname; # Define your hostname.

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  programs.niri.enable = true;
  programs.waybar.enable = true;

  environment.variables.EDITOR = "hx";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.groups.plugdev = { };
  users.users.archie = {
    isNormalUser = true;
    description = "Archie";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "dialout"
      "plugdev"
    ];
    shell = pkgs.fish;
  };

  virtualisation.containers.enable = true;
  virtualisation = {
    docker = {
      enable = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  programs.firefox.enable = true;
  programs.fish.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  environment.variables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    home-manager
    ghostty
    usbutils
    wl-clipboard-rs # Required for Helix
    bluetui # Bluetooth
    kickoff # App Launcher
    swayidle
    glib # For gsettings
    discord
    xwayland-satellite
    xremap
    xournalpp
    hyprlock
    slack
    vscode
  ];

  # Couldn't get sudo-less xremap to work
  systemd.services.xremap-system = {
    description = "System xremap service";
    enable = true;
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.xremap}/bin/xremap ${config.users.users.archie.home}/.config/xremap/config.yml";
    };
  };

  security.polkit.enable = true;

  fonts.packages = with pkgs; [
    font-awesome
    nerd-fonts.jetbrains-mono
    jetbrains-mono
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
