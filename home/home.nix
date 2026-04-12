{ pkgs, lib, ... }:
let
in
{
  home.username = "archie";
  home.homeDirectory = "/home/archie";

  nixpkgs.config.allowUnfree = true;

  modules.core-cli.enable = true;
  modules.core-gui.enable = true;

  home.packages = with pkgs; [
    usbutils
    bluetui # Bluetooth
    discord
    xournalpp
    slack
    vscode
    fastfetch
    ripgrep
    fd
    bat
    asciinema_3
    fzf
    zoxide
    fuzzel
    mako
    unzip
    lxsession
    lazydocker
    devcontainer
    popsicle
    mixxx
    chezmoi
    age
  ];

  programs.home-manager.enable = true;

  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

}
