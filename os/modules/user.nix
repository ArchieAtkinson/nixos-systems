{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user;
in
{

  options.modules.user = {
    archie = lib.mkEnableOption "Enable 'archie' user";
  };

  config = lib.mkIf cfg.archie {
    programs.fish.enable = true; # Required for system shell

    users.groups.plugdev = { };

    users.users.archie = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$SN1/W4HroOxr3kt8ADvg50$N.J8jOpSbzFqO6.9u/Kp1Z166u87emCJi89WeaY6c8D";
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
  };
}
