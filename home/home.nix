{ pkgs, lib, ... }:
let
in
{
  home.username = "archie";
  home.homeDirectory = "/home/archie";

  modules.core-cli.enable = true;

  programs.firefox.enable = true;

  nixpkgs.config.segger-jlink.acceptLicense = true;
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    usbutils
    wl-clipboard-rs # Required for Helix
    bluetui # Bluetooth
    kickoff # App Launcher
    swayidle
    discord
    xournalpp
    hyprlock
    slack
    vscode
    ghostty
    kicad-unstable
    fastfetch
    nixfmt
    nixd
    ripgrep
    fd
    bat
    wget
    asciinema_3
    fzf
    zoxide
    fuzzel
    mako
    unzip
    lxsession
    minicom
    lazydocker
    devcontainer
    nrfconnect
    nrf-udev
    # steam-tui
    # steamcmd
    sdrpp
    popsicle
    segger-jlink
    mixxx
    chezmoi
    age
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "segger-jlink-qt4-874"
  ];

  programs.home-manager.enable = true;

  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

}
