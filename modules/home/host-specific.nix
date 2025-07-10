{ config, lib, pkgs, hostname, ... }:

with lib;

let cfg = config.personal.host-specific;
in {
  options.personal.host-specific = {
    enable = mkEnableOption "Host-specific configurations";

    isLaptop = mkOption {
      type = types.bool;
      default = hostname == "mordor" || hostname == "betazed";
      description = "Whether the current host is a laptop";
    };

    hasBluetooth = mkOption {
      type = types.bool;
      default = hostname == "mordor" || hostname == "betazed";
      description = "Whether the current host has bluetooth";
    };

    primaryMonitor = mkOption {
      type = types.str;
      default = if (hostname == "mordor" || hostname == "betazed") then
        "eDP-1"
      else
        "DP-3";
      description = "The primary monitor for this host";
    };

    batteryDevice = mkOption {
      type = types.nullOr types.str;
      default = if cfg.isLaptop then "BAT0" else null;
      description = "Battery device name, if applicable";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Base configuration that applies to all hosts
    {
      # Common settings
    }

    # Laptop-specific configuration
    (mkIf cfg.isLaptop {
      services.cbatticon = mkIf (cfg.batteryDevice != null) {
        enable = true;
        criticalLevelPercent = 10;
        commandCriticalLevel =
          "${pkgs.libnotify}/bin/notify-send 'Battery critically low!'";
        lowLevelPercent = 20;
      };

      home.packages = with pkgs; [ light acpi tlp ];
    })

    # Bluetooth configuration
    (mkIf cfg.hasBluetooth {
      services.blueman-applet.enable = true;
      home.packages = with pkgs; [ bluez bluez-tools ];
    })
  ]);
}
