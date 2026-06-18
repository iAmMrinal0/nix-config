{ config, pkgs, ... }:

let
  colors = config.personal.theming.colors;
  currentTrack = "${pkgs.my.scripts.current-track}/bin/current-track";
  bluetoothBattery = "${pkgs.my.scripts.bluetooth-battery}/bin/bluetooth-battery";
  dunstToggle = "${pkgs.my.scripts.i3dunst-toggle}/bin/i3dunst-toggle";
  playerctl = "${pkgs.playerctl}/bin/playerctl --player=spotify";
  dunstctl = "${pkgs.dunst}/bin/dunstctl";
  gsimplecal = "${pkgs.gsimplecal}/bin/gsimplecal";
  # df-based root-fs usage so the bar matches `df` exactly: used / usable
  # (excludes the ext4 root-reserved blocks). i3status-rust's disk_space
  # block reports used/total instead, which reads ~5% lower.
  diskUsage = pkgs.writeShellScript "i3status-disk-usage" ''
    pct=$(${pkgs.coreutils}/bin/df --output=pcent / | ${pkgs.coreutils}/bin/tail --lines=1 | ${pkgs.coreutils}/bin/tr --delete --complement '0-9')
    if [ "$pct" -ge 90 ]; then state=Critical; elif [ "$pct" -ge 80 ]; then state=Warning; else state=Idle; fi
    printf '{"icon":"disk_drive","state":"%s","text":"%s%%"}\n' "$state" "$pct"
  '';
in {
  # Popup calendar for the time block; scroll on the block or popup to switch months
  xdg.configFile."gsimplecal/config".text = ''
    show_calendar = 1
    show_timezones = 1
    show_week_numbers = 1
    mark_today = 1
    clock_format = %H:%M
    clock_label = UTC
    clock_tz = :UTC
    clock_label = Stockholm
    clock_tz = :Europe/Stockholm
    clock_label = India
    clock_tz = :Asia/Kolkata
    # Deliberate: with focus_follows_mouse, unfocus-close fires on mere hover.
    # Close by clicking the bar's time block again (second invocation toggles).
    close_on_unfocus = 0
    mainwindow_decorated = 0
    mainwindow_keep_above = 1
    mainwindow_sticky = 1
    mainwindow_skip_taskbar = 1
    mainwindow_resizable = 0
    mainwindow_position = mouse
  '';

  programs.i3status-rust = {
    enable = true;
    bars.default = {
      icons = "awesome6";
      theme = "plain";
      settings.theme = {
        theme = "plain";
        overrides = {
          idle_bg = colors.bg0;
          idle_fg = colors.fg;
          info_bg = colors.bg0;
          info_fg = colors.aqua;
          good_bg = colors.bg0;
          good_fg = colors.green;
          warning_bg = colors.bg0;
          warning_fg = colors.yellow;
          critical_bg = colors.bg0;
          critical_fg = colors.red;
          separator = " · ";
          separator_bg = colors.bg0;
          separator_fg = colors.comment;
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
          # Two interface-pinned net blocks. A regex `device` keeps the VPN
          # tunnel (tun0 / tailscale0) from being selected. Each hides when
          # its interface is down/missing (inactive_format + missing_format
          # empty), so only the connected link shows. NOTE: the previous
          # `device = "auto"` was a bug — it matched an interface literally
          # named "auto", so this block rendered nothing.
          block = "net";
          device = "^wl";
          format = " $icon $ssid ";
          format_alt = " $icon $signal_strength $ssid {$speed_down.eng(prefix:K) / $speed_up.eng(prefix:K) |}";
          inactive_format = "";
          missing_format = "";
        }
        {
          block = "net";
          device = "^(en|eth)";
          format = " $icon $device ";
          format_alt = " $icon $device {$speed_down.eng(prefix:K) / $speed_up.eng(prefix:K) |}";
          inactive_format = "";
          missing_format = "";
        }
        {
          block = "load";
          interval = 5;
          format = " $icon $1m.eng(w:4) ";
        }
        {
          # Root-filesystem usage. Surfaced so a Nix store / worktree
          # blowup is visible before it runs the disk dry. Driven by df
          # (see diskUsage) so the percentage matches `df`; state colours
          # the block yellow at >=80% and red at >=90%.
          block = "custom";
          command = "${diskUsage}";
          json = true;
          interval = 60;
        }
        {
          block = "battery";
          driver = "sysfs";
          format = " $icon $percentage ";
          charging_format = " $icon $percentage ";
          empty_format = " $icon $percentage ";
          full_format = " $icon $percentage ";
          not_charging_format = " $icon $percentage ";
        }
        {
          block = "custom";
          command = bluetoothBattery;
          interval = 30;
        }
        {
          block = "time";
          interval = 60;
          format = " $icon $timestamp.datetime(f:'W%V · %a %d %b · %H:%M') ";
          click = [
            { button = "left"; cmd = gsimplecal; } # toggle calendar popup
            { button = "up"; cmd = "${gsimplecal} prev_month"; }
            { button = "down"; cmd = "${gsimplecal} next_month"; }
          ];
        }
        {
          block = "custom";
          command = dunstToggle;
          interval = 2;
          click = [
            { button = "right"; cmd = "${dunstctl} set-paused toggle"; }
          ];
        }
      ];
    };
  };
}
