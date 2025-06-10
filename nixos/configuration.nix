{ config, pkgs, ... }:
{
  nix.settings.experimental-features = "nix-command flakes";

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
    
  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
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

  programs.command-not-found.enable = false;

  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
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

  users.users.archie = {
    isNormalUser = true;
    description = "Archie";
    extraGroups = [ "networkmanager" "wheel"];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  programs.firefox.enable = true;
  programs.yazi.enable = true;
  programs.fish.enable = true;
  programs.direnv = {
    enable = true;
    silent = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  environment.systemPackages = with pkgs; [
      helix
      lazygit
      neofetch
      ghostty
      just
      git
      stow
      zellij
      typos-lsp
      usbutils
      wl-clipboard-rs # Required for Helix
      bluetui # Bluetooth
      kickoff # App Launcher
      swaylock-effects
      swayidle
      local.todui
      glib # For gsettings
      nil
      discord
      xwayland-satellite
      xremap
      ripgrep
      fd
      bat
      wget
      asciinema_3
      xournalpp
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
