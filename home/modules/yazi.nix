{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.yazi;
in
{

  options.modules.yazi = {
    enable = lib.mkEnableOption "Enable Yazi";
  };

  config = lib.mkIf cfg.enable {
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
  };
}
