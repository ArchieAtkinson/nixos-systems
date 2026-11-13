{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  home.username = "archie";
  home.homeDirectory = "/home/archie";

  nixpkgs.config.allowUnfree = true;

  modules.core-cli.enable = true;
  modules.core-gui.enable = true;
  modules.nix-tools.enable = true;
  modules.opencode.enable = true;

  modules.lan-mouse = {
    enable = true;
    clients = [
      {
        position = "left";
        hostname = "192.168.0.67";
      }
    ];
  };

  home.packages = with pkgs; [
    inputs.handy.packages.${pkgs.stdenv.hostPlatform.system}.default
    wtype
    kicad
    usbutils
    bluetui
    xournalpp
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
    chezmoi
    age
  ];

  programs.home-manager.enable = true;

  # Pin to the release the system was installed with; check that release's notes before changing.
  home.stateVersion = "25.05";

}
