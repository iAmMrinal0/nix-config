{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.xserver;
in {
  options.modules.xserver = {
    enable = mkEnableOption "Enable XServer";

    videoDrivers = mkOption {
      type = types.listOf types.str;
      default = [ "modesetting" "displaylink" ];
      description = "Video drivers to use";
    };

    windowManager = {
      i3 = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable i3 window manager";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.xserver = {
      enable = true;
      exportConfiguration = true;
      # dpi = 160;
      xkb = {
        layout = "us,se";
        variant = "";
        options = "grp:switch";
      };
      desktopManager = { xterm.enable = false; };
      displayManager = {
        sessionCommands = ''
          ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY
        '';
      };
      videoDrivers = cfg.videoDrivers;
      windowManager.i3 = mkIf cfg.windowManager.i3.enable {
        enable = true;
        extraPackages = [
          pkgs.dmenu
          pkgs.rofi
          pkgs.i3lock
          pkgs.xkb-switch
        ];
        # package = pkgs.i3-gaps;
      };
    };
    security.pam.services.i3lock.enable = mkIf cfg.windowManager.i3.enable true;
  };
}
