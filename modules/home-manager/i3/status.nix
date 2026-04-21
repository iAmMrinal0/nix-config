{ config, pkgs, ... }:

let
  colors = config.personal.theming.colors;
  currentTrack = "${pkgs.scripts.current-track}/bin/current-track";
  bluetoothBattery = "${pkgs.scripts.bluetooth-battery}/bin/bluetooth-battery";
  dunstToggle = "${pkgs.scripts.i3dunst-toggle}/bin/i3dunst-toggle";
  playerctl = "${pkgs.playerctl}/bin/playerctl --player=spotify";
  dunstctl = "${pkgs.dunst}/bin/dunstctl";
in {
  programs.i3status-rust = {
    enable = true;
    bars.default = {
      icons = "awesome6";
      theme = "plain";
      settings.theme = {
        theme = "slick";
        overrides = {
          idle_bg = colors.bg0;
          idle_fg = colors.fg;
          info_bg = colors.bg1;
          info_fg = colors.aqua;
          good_bg = colors.bg1;
          good_fg = colors.green;
          warning_bg = colors.bg1;
          warning_fg = colors.yellow;
          critical_bg = colors.bg1;
          critical_fg = colors.red;
        };
      };
      blocks = [
        {
          block = "custom";
          command = currentTrack;
          interval = 2;
          click = [
            { button = "left"; cmd = "${playerctl} play-pause"; }
            { button = "right"; cmd = "${playerctl} play-pause"; }
            { button = "up"; cmd = "${playerctl} previous"; }
            { button = "down"; cmd = "${playerctl} next"; }
          ];
        }
        {
          block = "sound";
          format = " $icon {$volume.eng(w:2)|muted} ";
          click = [
            { button = "left"; cmd = "${pkgs.pavucontrol}/bin/pavucontrol"; }
          ];
        }
        {
          block = "net";
          device = "auto";
          format = " $icon $ssid ";
          format_alt = " $icon $signal_strength $ssid {$speed_down.eng(prefix:K) / $speed_up.eng(prefix:K) |}";
          missing_format = "";
        }
        {
          block = "load";
          interval = 5;
          format = " $icon $1m.eng(w:4) ";
        }
        {
          block = "battery";
          driver = "sysfs";
          format = " $icon $percentage ";
          charging_format = " $icon $percentage ";
          empty_format = " $icon $percentage ";
          full_format = " $icon ";
        }
        {
          block = "custom";
          command = bluetoothBattery;
          interval = 30;
        }
        {
          block = "custom";
          command = dunstToggle;
          interval = 2;
          click = [
            { button = "right"; cmd = "${dunstctl} set-paused toggle"; }
          ];
        }
        {
          block = "time";
          interval = 60;
          format = " $icon $timestamp.datetime(f:'%a %d %b %H:%M') ";
        }
      ];
    };
  };
}
