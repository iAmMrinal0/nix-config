{ config, lib, pkgs, hostname, ... }:

with lib;

let cfg = config.personal.host-specific;
in {
  options.personal.host-specific = {
    enable = mkEnableOption "Host-specific configurations";

    isLaptop = mkOption {
      type = types.bool;
      default = hostname == "mordor" || hostname == "betazed" || hostname
        == "cardassia";
      description = "Whether the current host is a laptop";
    };

    hasBluetooth = mkOption {
      type = types.bool;
      default = hostname == "mordor" || hostname == "betazed" || hostname
        == "cardassia";
      description = "Whether the current host has bluetooth";
    };

    primaryMonitor = mkOption {
      type = types.str;
      default = if (hostname == "mordor" || hostname == "betazed" || hostname
        == "cardassia") then
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
    # Laptop-specific configuration
    (mkIf cfg.isLaptop {
      services.cbatticon = mkIf (cfg.batteryDevice != null) {
        enable = true;
        criticalLevelPercent = 10;
        commandCriticalLevel =
          "${pkgs.libnotify}/bin/notify-send 'Battery critically low!'";
        lowLevelPercent = 20;
      };
      # Autostart disabled on BOTH stacks (WantedBy empty); each WM launches
      # cbatticon from its own startup. Sway-exec'd via sway/config.nix startup
      # — same reasoning as blueman/udiskie (Requires=tray.target and the
      # WAYLAND_DISPLAY race at session start). (No-op when batteryDevice is
      # null since the unit isn't generated.)
      systemd.user.services.cbatticon.Install.WantedBy =
        mkIf (cfg.batteryDevice != null) (mkForce [ ]);

      # i3 counterpart: with autostart off, the battery tray icon would be
      # missing under the i3 pick. There's no WAYLAND_DISPLAY race on X11, so
      # i3 just starts the unit from its startup list. Merges with the startup
      # entries in modules/home-manager/i3/config.nix.
      xsession.windowManager.i3.config.startup =
        mkIf (cfg.batteryDevice != null) [
          { command = "${pkgs.systemd}/bin/systemctl --user start cbatticon.service"; }
        ];

      # `light` was removed in 26.05 (unmaintained); brightnessctl is the
      # replacement and matches the i3 brightness keybinds + the udev
      # rules in base.nix.
      home.packages = with pkgs; [ brightnessctl acpi tlp ];
    })

    # Bluetooth configuration
    (mkIf cfg.hasBluetooth {
      services.blueman-applet.enable = true;
      home.packages = with pkgs; [ bluez bluez-tools ];
    })
  ]);
}
