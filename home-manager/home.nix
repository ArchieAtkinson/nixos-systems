{ pkgs, lib, ... }:
let
  local = pkgs.callPackage ./pkgs { inherit (pkgs) lib; };
in
{
  home.username = "archie";
  home.homeDirectory = "/home/archie";

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    settings = {
      mgr = {
        show_hidden = true;
        sort_by = "mtime";
        sort_reverse = true;
      };
    };
    flavors = {
      inherit (pkgs.yazi-flavors)
        catppuccin-macchiato
        catppuccin-latte
        ;
    };
    theme.flavor = {
      dark = "catppuccin-macchiato";
      light = "catppuccin-latte";
    };
  };

  home.shell.enableFishIntegration = true;

  programs.direnv = {
    enable = true;
    silent = true;
    nix-direnv.enable = true;
  };

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
    fish
    fishPlugins.pure
    fishPlugins.sponge
    local.berth
    helix
    lazygit
    just
    git
    zellij
    typos-lsp
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

  # programs.nh = {
  #   enable = true;
  #   clean.enable = true;
  #   clean.extraArgs = "--keep-since 4d --keep 3";
  #   flake = "/home/archie/nixos-systems";
  # };

  programs.home-manager.enable = true;

  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

}
