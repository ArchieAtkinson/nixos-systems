{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.xremap;
in
{

  options.modules.xremap = {
    enable = lib.mkEnableOption "Enable xremap services";
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      xremap
    ];

    # Restore libinput's disable-while-typing by tagging xremap's virtual
    # keyboard as internal so it pairs with the touchpad.
    # MatchName is essential: without it MatchUdevType=keyboard matches *every*
    # keyboard, which makes libinput disable external USB/Bluetooth keyboards in
    # tablet mode as well as the built-in one.
    environment.etc."libinput/local-overrides.quirks".text = ''
      [xremap]
      MatchUdevType=keyboard
      MatchName=xremap*
      AttrKeyboardIntegration=internal
    '';

    # System service: xremap needs to read event devices directly.
    systemd.services.xremap-system = {
      description = "System xremap service";
      enable = true;
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.xremap}/bin/xremap ${./resources/xremap.yml}";
      };
    };

  };
}
