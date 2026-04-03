{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.audio;
in
{

  options.modules.audio = {
    enable = lib.mkEnableOption "Enable Audio";
  };

  config = lib.mkIf cfg.enable {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    nixpkgs.config.pulseaudio = true;

    environment.systemPackages = [
      pkgs.pulseaudio
    ];
  };
}
