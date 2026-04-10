{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.common;
in
{

  options.modules.common = {
    enable = lib.mkEnableOption "Enable Common Settings";
  };

  config = lib.mkIf cfg.enable {

    nix.settings.experimental-features = "nix-command flakes";
    nixpkgs.config.allowUnfree = true;
    programs.command-not-found.enable = false;
    security.polkit.enable = true;
    networking.networkmanager.enable = true;
    services.fwupd.enable = true;
    services.printing.enable = true;

    nixpkgs.overlays = [
      (final: prev: {
        localPkgs = final.callPackage ./pkgs { inherit (pkgs) lib; };
      })
    ];

    environment.variables.EDITOR = "hx";

    console.keyMap = "uk";
    services.xserver = {
      enable = true;
      xkb = {
        layout = "gb";
        variant = "";
      };
    };

    fonts.packages = with pkgs; [
      font-awesome
      nerd-fonts.jetbrains-mono
      jetbrains-mono
    ];

    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
    };

  };
}
