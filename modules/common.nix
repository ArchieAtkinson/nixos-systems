{
  config,
  pkgs,
  ...
}:

let
in
{

  modules.xremap.enable = true;
  modules.sops.enable = true;
  modules.user.archie = true;
  modules.audio.enable = true;
  modules.virtualisation.enable = true;
  modules.vpn.enable = true;
  modules.locale.GB = true;

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

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

}
