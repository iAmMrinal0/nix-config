{ pkgs, ... }:

let
  bluetooth_battery = pkgs.callPackage ../scripts/bluetooth_battery.nix { };
  getStatus = pkgs.callPackage ../scripts/songStatus.nix { inherit polybar; };
  dunstNotifToggle = pkgs.callPackage ../scripts/dunstNotifToggle.nix { };

  polybar = pkgs.polybarFull.override {
    i3GapsSupport = true;
    alsaSupport = true;
  };
  mf = "#383838";

  bg = "#000000";
  fg = "#FFFFFF";

  primary = "#504945";

  secondary = "#ebdbb2";

  tertiary = "#1d2021";

  quaternary = "#ecf0f1";

  urgency = "#e74c3c";
  common = {
    cursor-click = "pointer";
    font-0 = "Source Code Pro:size=12;3";
    font-1 = "Font Awesome 5 Free Regular:style=Regular:size=12;0";
    font-2 = "FuraCode Nerd Font:style=Bold:size=12;3";
  };

in {
  enable = true;

  package = polybar;

  script = builtins.readFile
    (pkgs.callPackage ../scripts/polybarLaunch.nix { inherit polybar; });

  config = {
    "global/wm" = {
      margin-bottom = 0;
      margin-top = 0;
    };

    "bar/top" = {
      bottom = false;
      fixed-center = true;
      enable-ipc = true;

      width = "100%";
      height = 19;
      offset-x = "1%";

      scroll-up = "#i3.next";
      scroll-down = "#i3.prev";

      background = bg;
      foreground = fg;

      modules-left = "i3 topleft-light";
      modules-center = "bottomright-dark title bottomleft-dark";
      modules-right =
        "topright-light wireless bottomleft-light topright-dark audio bottomleft-dark topright-light date";

      locale = "en_US.UTF-8";
    } // common;

    "bar/bottom" = {
      bottom = true;
      fixed-center = true;
      enable-ipc = true;

      width = "100%";
      height = 19;

      offset-x = "1%";

      background = bg;
      foreground = fg;

      radius-top = 0;

      tray-position = "left";
      tray-detached = false;
      tray-maxsize = 15;
      tray-background = bg;
      tray-offset-x = -20;
      tray-offset-y = 0;
      tray-padding = 5;
      tray-scale = 1;
      padding = 0;

      modules-left = "dunst";
      modules-center =
        "bottomright-dark spotify spotify-prev spotify-play-pause spotify-next bottomleft-dark";
      modules-right =
        "bottomright-dark bluetooth topleft-dark bottomright-light cpu topleft-light bottomright-dark memory topleft-dark bottomright-light battery";

      locale = "en_US.UTF-8";
    } // common;

    "settings" = {
      throttle-output = 5;
      throttle-output-for = 10;

      screenchange-reload = true;

      compositing-background = "source";
      compositing-foreground = "over";
      compositing-overline = "over";
      comppositing-underline = "over";
      compositing-border = "over";

      pseudo-transparency = "false";
    };

    "module/dunst" = {
      type = "custom/ipc";
      initial = 1;

      format-foreground = secondary;

      hook-0 = "echo ''";
      hook-1 = "echo ''";
      exec = "${dunstNotifToggle} on &";
      click-left = "${dunstNotifToggle} off &";
      click-right = "${dunstNotifToggle} on &";
    };

    "module/spotify" = {
      type = "custom/script";
      tail = true;
      format = " <label>";
      exec = "${getStatus}/bin/getStatus";
      label-maxlen = 30;
      format-foreground = secondary;
      format-background = tertiary;
    };

    "module/spotify-prev" = {
      type = "custom/script";
      exec = "echo '  '";
      format = "<label>";
      click-left = "${pkgs.playerctl}/bin/playerctl previous spotify";
      format-foreground = secondary;
      format-background = tertiary;
    };

    "module/spotify-play-pause" = {
      type = "custom/ipc";
      hook-0 = "echo '  '";
      hook-1 = "echo '  '";
      hook-2 = "echo '  '";
      initial = 2;
      click-left = "${pkgs.playerctl}/bin/playerctl play-pause spotify";
      format-foreground = secondary;
      format-background = tertiary;
    };

    "module/spotify-next" = {
      type = "custom/script";
      exec = "echo '  '";
      format = "<label>";
      click-left = "${pkgs.playerctl}/bin/playerctl next spotify";
      format-foreground = secondary;
      format-background = tertiary;
    };

    "module/audio" = {
      type = "internal/pulseaudio";

      format-volume = "墳 <label-volume>";
      format-volume-padding = 1;
      format-volume-foreground = secondary;
      format-volume-background = tertiary;
      label-volume = "%percentage%%";

      format-muted = "<label-muted>";
      format-muted-padding = 1;
      format-muted-foreground = secondary;
      format-muted-background = tertiary;
      format-muted-prefix = "婢 ";
      format-muted-prefix-foreground = urgency;
      format-muted-overline = bg;

      label-muted = "Mute";
    };

    "module/battery" = {
      type = "internal/battery";
      full-at = 99;
      battery = "BAT1";
      adapter = "AC";

      poll-interval = 2;

      label-full = " 100%";
      format-full-padding = 1;
      format-full-foreground = secondary;
      format-full-background = primary;

      format-charging = " <animation-charging> <label-charging>";
      format-charging-padding = 1;
      format-charging-foreground = secondary;
      format-charging-background = primary;
      label-charging = "%percentage%% %time%";
      animation-charging-0 = "";
      animation-charging-1 = "";
      animation-charging-2 = "";
      animation-charging-3 = "";
      animation-charging-4 = "";
      animation-charging-framerate = 500;

      format-discharging = "<ramp-capacity> <label-discharging>";
      format-discharging-padding = 1;
      format-discharging-foreground = secondary;
      format-discharging-background = primary;
      label-discharging = "%percentage%% %time%";
      ramp-capacity-0 = "";
      ramp-capacity-0-foreground = urgency;
      ramp-capacity-1 = "";
      ramp-capacity-1-foreground = urgency;
      ramp-capacity-2 = "";
      ramp-capacity-3 = "";
      ramp-capacity-4 = "";
    };

    "module/cpu" = {
      type = "internal/cpu";

      interval = "0.5";

      format = " <label>";
      format-foreground = secondary;
      format-background = primary;
      format-padding = 1;

      label = "%percentage%%";
    };

    "module/date" = {
      type = "internal/date";

      interval = "1.0";

      time = "%H:%M";
      time-alt = "%Y-%m-%d%";

      format = "<label>";
      format-padding = 2;
      format-foreground = secondary;
      format-background = primary;

      label = "%time%";
    };

    "module/i3" = {
      type = "internal/i3";
      pin-workspaces = false;
      strip-wsnumbers = true;
      format = "<label-state> <label-mode>";
      format-background = primary;

      ws-icon-0 = "1 ;";
      ws-icon-1 = "2 ;";
      ws-icon-2 = "3 ;";
      ws-icon-3 = "4 ♪;♪";
      ws-icon-4 = "5 ;";
      ws-icon-5 = "9 ;";
      ws-icon-default = "";

      label-mode = "%mode%";
      label-mode-padding = 2;

      label-unfocused = "%icon%";
      label-unfocused-foreground = tertiary;
      label-unfocused-padding = 2;

      label-focused = "%index% %icon%";
      label-focused-font = 1;
      label-focused-foreground = secondary;
      label-focused-padding = 2;

      label-visible = "%icon%";
      label-visible-padding = 2;

      label-urgent = "%index%";
      label-urgent-foreground = urgency;
      label-urgent-padding = 2;

      label-separator = "";
    };

    "module/title" = {
      type = "internal/xwindow";
      format = "<label>";
      label = "%title%";
      label-maxlen = 70;
      format-foreground = secondary;
      format-background = tertiary;
    };

    "module/memory" = {
      type = "internal/memory";

      interval = 3;

      format = " <label>";
      format-background = tertiary;
      format-foreground = secondary;
      format-padding = 1;

      label = "%percentage_used%%";
    };

    "module/bluetooth" = {
      type = "custom/script";

      interval = 30;

      format = " <label>";
      format-background = tertiary;
      format-foreground = secondary;
      format-padding = 1;

      exec = "${bluetooth_battery}";
    };

    "module/network" = {
      type = "internal/network";
      interface = "enp3s0";

      interval = "1.0";

      accumulate-stats = true;
      unknown-as-up = true;

      format-connected = "<label-connected>";
      format-connected-background = mf;
      format-connected-underline = bg;
      format-connected-overline = bg;
      format-connected-padding = 2;
      format-connected-margin = 0;

      format-disconnected = "<label-disconnected>";
      format-disconnected-background = mf;
      format-disconnected-underline = bg;
      format-disconnected-overline = bg;
      format-disconnected-padding = 2;
      format-disconnected-margin = 0;

      label-connected = "D %downspeed:2% | U %upspeed:2%";
      label-disconnected = "DISCONNECTED";
    };

    "module/wireless" = {
      type = "internal/network";
      interface = "wlp3s0";
      interval = "3.0";
      format-connected-padding = 1;
      format-connected-foreground = secondary;
      format-connected-background = primary;
      format-connected = " <label-connected>";
      label-connected = "%essid% %local_ip%";
    };

    "module/topleft-dark" = {
      type = "custom/text";
      content = "";
      content-foreground = tertiary;
      content-background = bg;
    };

    "module/topleft-light" = {
      type = "custom/text";
      content = "";
      content-foreground = primary;
      content-background = bg;
    };

    "module/bottomright-dark" = {
      type = "custom/text";
      content = "";
      content-foreground = tertiary;
      content-background = bg;
    };

    "module/bottomleft-dark" = {
      type = "custom/text";
      content = "";
      content-foreground = tertiary;
      content-background = bg;
    };

    "module/bottomleft-light" = {
      type = "custom/text";
      content = "";
      content-foreground = primary;
      content-background = bg;
    };

    "module/topright-dark" = {
      type = "custom/text";
      content = "";
      content-foreground = tertiary;
      content-background = bg;
    };

    "module/topright-light" = {
      type = "custom/text";
      content = "";
      content-foreground = primary;
      content-background = bg;
    };

    "module/bottomright-light" = {
      type = "custom/text";
      content = "";
      content-foreground = primary;
      content-background = bg;
    };
  };
}
