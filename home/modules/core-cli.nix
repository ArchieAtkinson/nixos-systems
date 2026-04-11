{
  config,
  lib,
  pkgs,
  ...
}:

let
  local = pkgs.callPackage ./../pkgs { inherit (pkgs) lib; };
  cfg = config.modules.core-cli;
in
{

  options.modules.core-cli = {
    enable = lib.mkEnableOption "Enable Core CLI Programs";
  };

  config = lib.mkIf cfg.enable {
    modules.yazi.enable = true;

    home.packages = with pkgs; [
      fish
      fishPlugins.pure
      fishPlugins.sponge
      helix
      lazygit
      zellij
      typos-lsp
      local.berth
      just
      git
    ];

    home.shell.enableFishIntegration = true;

    programs.direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
    };

  };
}
