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

    environment.systemPackages = with pkgs; [
      pavucontrol
    ];

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;

      # Keep the graph from running tiny (Sunshine's capture was pushing it to
      # quantum 256 / ~5ms, which is fragile under load). Floor it at 1024.
      extraConfig.pipewire."10-clock" = {
        context.properties = {
          default.clock.quantum = 1024;
          default.clock.min-quantum = 1024;
        };
      };
    };

  };
}
