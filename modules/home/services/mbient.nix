{ config, pkgs, lib, osConfig, hostname, ... }:

with lib;

let cfg = config.personal.mbient;
in {
  options.personal.mbient = {
    enable = mkEnableOption "reporting this machine's state";

    host = mkOption {
      type = types.str;
      default = hostname;
      description = ''
        Name this machine reports under. State is keyed by host, so two
        machines reporting at once merge rather than fight.
      '';
    };

    urlFile = mkOption {
      type = types.path;
      default = osConfig.sops.secrets.mbient-url.path;
      description = ''
        File holding the base URL.
      '';
    };

    tokenFile = mkOption {
      type = types.path;
      default = osConfig.sops.secrets.mbient-token.path;
      description = "File holding the bearer token.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.mbient-report = {
      Unit = {
        Description = "Report call, music and lock state";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        # Secrets arrive with the system, not the session, so an early start
        # can fail. Keep retrying rather than latching off.
        StartLimitBurst = 10;
        StartLimitIntervalSec = 600;
      };

      Service = {
        Type = "simple";
        Environment = [
          "MBIENT_URL_FILE=${cfg.urlFile}"
          "MBIENT_TOKEN_FILE=${cfg.tokenFile}"
          "MBIENT_HOST=${cfg.host}"
        ];
        ExecStart = "${pkgs.my.scripts.mbient-report}/bin/mbient-report";
        Restart = "always";
        RestartSec = 10;
      };

      # No tray.target or WAYLAND_DISPLAY dependency, so unlike the applets it
      # can start with the session normally.
      Install.WantedBy = [ "default.target" ];
    };
  };
}
