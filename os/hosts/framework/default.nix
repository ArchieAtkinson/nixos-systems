{
  config,
  pkgs,
  hostname,
  inputs,
  ...
}:
let
  # Run on Moonlight connect: enable the virtual output, then restart Sunshine
  # (rate-limited) so it re-binds RTSP and re-selects the now-enabled output.
  sunshineReset = pkgs.writeShellScript "sunshine-prep" ''
    export PATH="/run/current-system/sw/bin:$PATH"

    # Stop lan-mouse before changing the display layout: its input-capture
    # panics when outputs change, and it shouldn't grab input back to the
    # Windows PC while that PC is the Moonlight display.
    systemctl --user stop lan-mouse || true

    niri msg output sunshine on || true

    guard="''${XDG_RUNTIME_DIR:-/tmp}/sunshine-rtsp-reset"
    now=$(date +%s)
    last=0
    if [ -e "$guard" ]; then last=$(stat -c %Y "$guard" 2>/dev/null || echo 0); fi
    if [ $((now - last)) -gt 60 ]; then
      touch "$guard"
      systemctl --user restart sunshine
    fi
  '';
  sunshineUndo = pkgs.writeShellScript "sunshine-undo" ''
    export PATH="/run/current-system/sw/bin:$PATH"
    niri msg output sunshine off || true
    systemctl --user start lan-mouse || true
  '';
in
{

  programs.ydotool = {
    enable = true;
  };

  users.users.archie.extraGroups = [ "input" "uinput" ];

  modules.common.enable = true;
  modules.gui.enable = true;
  modules.xremap.enable = true;
  modules.sops.enable = true;
  modules.user.archie = true;
  modules.audio.enable = true;
  modules.virtualisation.enable = true;
  modules.vpn.proton-vpn = true;
  modules.locale.GB = true;
  modules.syncthing.enable = true;
  modules.opencode.enable = true;
  modules.udev-rules.serial-tty = true;

  programs.niri.package = inputs.biri.packages.${pkgs.stdenv.hostPlatform.system}.niri;

  # Intel VAAPI for hardware video encoding (Sunshine)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      capture = "wlr";
      output_name = "sunshine";
      # More forward error correction to ride out Wi-Fi jitter/loss on audio.
      fec_percentage = 50;
      global_prep_cmd = ''[{"do":"${sunshineReset}","undo":"${sunshineUndo}"}]'';
    };
  };

  networking.firewall.allowedUDPPorts = [ 4242 ]; # lan-mouse

  programs.steam = {
    enable = true;
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  networking.hostName = hostname;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.gnome-session ];
  };

  environment.systemPackages = with pkgs; [
    home-manager
    gnome-network-displays
    glib-networking # TLS backend for GIO
    gsettings-desktop-schemas
    framework-tool
    intel-gpu-tools # intel_gpu_top, for checking iGPU engine load
  ];

  programs.dconf.enable = true;

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.variables.NIXOS_OZONE_WL = "1";

  # Pin to the release the system was installed with; check that release's notes before changing.
  system.stateVersion = "25.11";

}
