{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.lan-mouse;

  inherit (lib) mkIf mkEnableOption mkOption types;

  clientType = types.submodule {
    options = {
      position = mkOption {
        type = types.enum [
          "left"
          "right"
          "top"
          "bottom"
        ];
        description = "Which screen edge this peer sits on.";
      };
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Peer hostname (optional if ips is set).";
      };
      ips = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Known IP addresses for the peer.";
      };
    };
  };

  # enter/leave are called by lan-mouse; `guard` wraps your lock command, e.g.
  # timeout 600 '~/.local/bin/lan-mouse-away guard hyprlock'.
  awayScript = pkgs.writeShellScript "lan-mouse-away" ''
    flag="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lan-mouse/away"
    case "''${1:-}" in
      enter)
        mkdir -p "$(dirname "$flag")"
        : > "$flag"
        ;;
      leave) rm -f "$flag" ;;
      guard)
        shift
        [ -e "$flag" ] || exec "$@"
        ;;
      *)
        echo "usage: lan-mouse-away {enter|leave|guard <command...>}" >&2
        exit 2
        ;;
    esac
  '';

  hook = "${config.home.homeDirectory}/.local/bin/lan-mouse-away";

  settings = {
    port = cfg.port;
    clients = map (c: {
      inherit (c) position;
      activate_on_startup = true;
      enter_hook = "${hook} enter";
      leave_hook = "${hook} leave";
    }
    // lib.optionalAttrs (c.hostname != null) { inherit (c) hostname; }
    // lib.optionalAttrs (c.ips != [ ]) { inherit (c) ips; }) cfg.clients;
  };

  configFile = (pkgs.formats.toml { }).generate "lan-mouse-config.toml" settings;
in
{
  options.modules.lan-mouse = {
    enable = mkEnableOption "lan-mouse keyboard/mouse sharing";

    package = mkOption {
      type = types.package;
      default = inputs.lan-mouse.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "inputs.lan-mouse.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "lan-mouse package to use.";
    };

    port = mkOption {
      type = types.port;
      default = 4242;
      description = "UDP port lan-mouse listens on.";
    };

    clients = mkOption {
      type = types.listOf clientType;
      default = [ ];
      description = "Peers the cursor can be sent to.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".local/bin/lan-mouse-away".source = awayScript;

    # Seed once; the daemon owns config.toml afterwards (hooks only live here).
    home.activation.lan-mouse-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      target="${config.xdg.configHome}/lan-mouse/config.toml"
      if [ ! -e "$target" ]; then
        run mkdir -p "$(dirname "$target")"
        run install -m 0644 ${configFile} "$target"
      fi
    '';

    systemd.user.services.lan-mouse = {
      Unit = {
        Description = "lan-mouse keyboard/mouse sharing";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        BindsTo = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/lan-mouse daemon";
        Restart = "on-failure";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -f %t/lan-mouse/away";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
