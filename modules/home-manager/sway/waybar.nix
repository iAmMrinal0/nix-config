{ config, lib, pkgs, ... }:

# Waybar replaces swaybar+i3status-rust under sway. Reason: swaybar's
# StatusNotifierItem (tray) handling only renders apps that ship embedded
# pixmap icons (Bitwarden, etc.). Apps that publish IconName (kdeconnect,
# blueman, transmission, cryptomator, …) render as the broken-icon
# placeholder. Waybar handles SNI properly.
#
# Installed unconditionally — the systemd user service is tied to
# sway-session.target, so on mordor (i3 + lightdm) it stays inert.
let
  colors = config.personal.theming.colors;
  currentTrack = "${pkgs.my.scripts.current-track}/bin/current-track";
  bluetoothBattery = "${pkgs.my.scripts.bluetooth-battery}/bin/bluetooth-battery";
  dunstToggle = "${pkgs.my.scripts.i3dunst-toggle}/bin/i3dunst-toggle";
  playerctl = "${pkgs.playerctl}/bin/playerctl --player=spotify";
  dunstctl = "${pkgs.dunst}/bin/dunstctl";
  pavucontrol = "${pkgs.pavucontrol}/bin/pavucontrol";
  pactl = "${pkgs.pulseaudio}/bin/pactl";

  # Shared config for all separators — waybar does NOT auto-strip the
  # `#N` instance suffix when looking up module config, so each separator
  # in `modules-right` needs a distinct key. Keys are reused via this
  # binding so the spec stays in one place.
  separator = {
    format = "·";
    tooltip = false;
    interval = "once";
  };
in {
  programs.waybar = {
    enable = true;
    # Managed by its systemd user unit (waybar.service, WantedBy
    # sway-session.target). The earlier setup launched waybar from
    # sway's exec startup with systemd.enable = false to dodge a
    # WAYLAND_DISPLAY-import race at session start, but that path made
    # multi-instance accidents possible (sway reload re-firing exec
    # lines, manual `waybar &` from a terminal during config tweaks
    # never getting reaped) — singleton enforcement only happens when
    # systemd owns the unit. The retry-budget bumps below let the
    # original env race resolve without permanently failing the unit;
    # same approach as kanshi.nix.
    systemd.enable = true;
    # One bar serves both Wayland sessions: targets is a LIST (unlike
    # kanshi's single-string systemdTarget), so the dual binding needs no
    # raw unit override — the HM module sets Install.WantedBy AND
    # Unit.PartOf to these, giving start+stop under whichever compositor
    # is running. Default would be [ wayland.systemd.target ] =
    # sway-session.target only.
    systemd.targets = [ "sway-session.target" "hyprland-session.target" ];

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 28;
        spacing = 4;

        # Both compositors' modules are listed; waybar disables (with a log
        # line, no crash) any module whose IPC it can't reach, so under sway
        # the hyprland/* pair is inert and vice versa. The per-WM env scrubs
        # (SWAYSOCK unset in hyprland's exec-once, HYPRLAND_INSTANCE_SIGNATURE
        # unset in sway's startup) keep the inactive pair from chasing a
        # stale socket. hyprland/workspaces renders the same labels as
        # sway/workspaces because the workspace defaultName rules carry the
        # i3/sway names (see modules/home-manager/hyprland/config.nix).
        modules-left = [ "sway/workspaces" "sway/mode" "hyprland/workspaces" "hyprland/submap" ];
        modules-center = [ ];
        modules-right = [
          "custom/current-track" "custom/sep1"
          "pulseaudio" "custom/sep2"
          "network" "custom/sep3"
          "cpu" "custom/sep4"
          "battery" "custom/sep5"
          "custom/bluetooth-battery" "custom/sep6"
          "custom/dunst" "custom/sep7"
          "clock" "custom/sep8"
          "tray"
        ];

        "custom/sep1" = separator;
        "custom/sep2" = separator;
        "custom/sep3" = separator;
        "custom/sep4" = separator;
        "custom/sep5" = separator;
        "custom/sep6" = separator;
        "custom/sep7" = separator;
        "custom/sep8" = separator;

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = false;
        };

        # Active only under Hyprland (see modules-left note above). format
        # pinned to {name} so the defaultName workspace labels render, and
        # scroll-cycling left unbound for parity with disable-scroll on the
        # sway module.
        "hyprland/workspaces" = {
          format = "{name}";
          all-outputs = false;
        };

        "sway/window" = {
          format = "{title}";
          max-length = 60;
        };

        "custom/current-track" = {
          exec = currentTrack;
          interval = 2;
          on-click = "${playerctl} play-pause";
          on-click-right = "${playerctl} play-pause";
          on-scroll-up = "${playerctl} previous";
          on-scroll-down = "${playerctl} next";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 muted";
          # Always show the volume icon. Without these overrides, waybar
          # auto-swaps to a headphone glyph when headphones are the active
          # sink, which conflicts with the bluetooth-battery script that
          # uses the headphone icon as its identifier.
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
            headphone = [ "󰕿" "󰖀" "󰕾" ];
            hands-free = [ "󰕿" "󰖀" "󰕾" ];
            headset = [ "󰕿" "󰖀" "󰕾" ];
            phone = [ "󰕿" "󰖀" "󰕾" ];
            portable = [ "󰕿" "󰖀" "󰕾" ];
            car = [ "󰕿" "󰖀" "󰕾" ];
            default-step = [ "󰕿" "󰖀" "󰕾" ];
          };
          on-click = pavucontrol;
          # Right-click to mute. Waybar's pulseaudio module has no
          # default right-click action — left-click opens pavucontrol
          # via the line above, so the mute toggle has to be wired up
          # explicitly here. Mirrors the volume-down/-up wheel binding
          # that lived in i3status-rust's [[block]] for sound on i3.
          on-click-right = "${pactl} set-sink-mute @DEFAULT_SINK@ toggle";
        };

        network = {
          # Default format: just the icon + ssid/ifname.
          format-wifi = "󰖩 {essid}";
          format-ethernet = "󰈀 {ifname}";
          format-disconnected = "󰖪";
          # Click → NetworkManager connection editor (full GUI for
          # picking/saving wifi networks, manages active-vs-available
          # state with familiar checkboxes/radio UI). Ships with the
          # networkmanager package by default.
          on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          # Click cycles to the alt format which shows signal strength and
          # live bandwidth — equivalent to i3status-rust's `format_alt`.
          # Click again to cycle back.
          format-wifi-alt = "󰖩 {signalStrength}% {essid} ↓{bandwidthDownBits} ↑{bandwidthUpBits}";
          format-ethernet-alt = "󰈀 {ifname} ↓{bandwidthDownBits} ↑{bandwidthUpBits}";
          # Hover-tooltip — same info as alt format, available without
          # clicking.
          tooltip-format-wifi = "{essid} ({signalStrength}%)\nIP: {ipaddr}/{cidr}\n↑ {bandwidthUpBits}  ↓ {bandwidthDownBits}";
          tooltip-format-ethernet = "{ifname}\nIP: {ipaddr}/{cidr}\n↑ {bandwidthUpBits}  ↓ {bandwidthDownBits}";
          tooltip-format-disconnected = "Disconnected";
          interval = 5;
        };

        cpu = {
          interval = 5;
          format = "󰍛 {load}";
        };

        battery = {
          states = {
            warning = 20;
            critical = 10;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        "custom/bluetooth-battery" = {
          exec = bluetoothBattery;
          interval = 30;
        };

        "custom/dunst" = {
          exec = dunstToggle;
          interval = 2;
          on-click-right = "${dunstctl} set-paused toggle";
        };

        clock = {
          # Chrono spec inside `{:...}` MUST start with `%`. Literals
          # (the icon, "W", "·", spaces) go either outside the braces
          # (passthrough) or after a `%X` token (chrono treats internal
          # non-`%` chars as literal). The leading "W" sits OUTSIDE the
          # braces because the spec can't start with a literal — putting
          # it inside silently empties the whole format. Result:
          #   "󰃭 W18 · Sun 03 May · 19:23"
          format = "󰃭 W{:%V · %a %d %b · %H:%M}";
          interval = 60;
          # Tooltip shows a calendar for the current month plus a header.
          # Scroll on the clock to step through months. To switch to a
          # full yearly view, change calendar.mode to "year" — readable
          # but the tooltip becomes much larger.
          tooltip-format = "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>";
          # Pin locale so the calendar uses ISO week numbers (Monday-start,
          # %V) instead of US convention (Sunday-start, %U), which puts
          # the week boundary one day off and would show W17 for what is
          # actually ISO W18.
          locale = "en_GB.UTF-8";
          calendar = {
            mode = "month";
            mode-mon-col = 3;
            weeks-pos = "left";
            on-scroll = 1;
            format = {
              months     = "<span color='${colors.aqua}'><b>{}</b></span>";
              days       = "<span color='${colors.fg}'>{}</span>";
              # Force ISO-8601 week number (Monday-start, no W0). Waybar's
              # default formatter uses `%U` which produces W0 for early-
              # January partial weeks and is off-by-one against ISO. The
              # `{:%V}` substitution overrides it with the chrono ISO
              # week format.
              weeks      = "<span color='${colors.comment}'><i>W{:%V}</i></span>";
              weekdays   = "<span color='${colors.comment}'><b>{}</b></span>";
              today      = "<span color='${colors.yellow}'><b><u>{}</u></b></span>";
            };
          };
          actions = {
            on-click-right = "mode";
            # Scroll up moves backward in time (previous month), scroll
            # down moves forward — matches the natural "scroll up to see
            # past" mental model used in chat apps and timelines.
            on-scroll-up   = "shift_down";
            on-scroll-down = "shift_up";
          };
        };

        tray = {
          icon-size = 22;
          spacing = 8;
        };
      };
    };

    style = ''
      * {
        font-family: "Source Code Pro", "Symbols Nerd Font Mono";
        font-size: 13px;
        font-weight: 500;
        min-height: 0;
        padding: 0;
        margin: 0;
      }

      window#waybar {
        background-color: ${colors.bg0};
        color: ${colors.fg};
        border-bottom: none;
      }

      tooltip {
        background-color: ${colors.bg0};
        border: 1px solid ${colors.comment};
      }

      tooltip label {
        color: ${colors.fg};
      }

      #workspaces {
        /* Zero left margin so the first workspace button reaches the
           screen's top-left corner (Fitt's law — the corner is an
           infinite-target click zone). 4px stays on the right to keep
           visual breathing room between the workspaces module and
           sway/mode. */
        margin: 0 4px 0 0;
      }

      #workspaces button {
        padding: 0 6px;
        background-color: transparent;
        color: ${colors.comment};
        border: none;
        border-radius: 0;
      }

      #workspaces button:hover {
        background-color: ${colors.bg2};
        box-shadow: none;
        text-shadow: none;
      }

      #workspaces button.focused,
      #workspaces button.visible {
        color: ${colors.fgBright};
      }

      #workspaces button.urgent {
        background-color: ${colors.urgent};
        color: ${colors.fgBright};
      }

      #window,
      #mode {
        padding: 0 8px;
        color: ${colors.fg};
      }

      #custom-current-track,
      #pulseaudio,
      #network,
      #cpu,
      #battery,
      #custom-bluetooth-battery,
      #custom-dunst,
      #clock,
      #tray {
        padding: 0 8px;
        color: ${colors.fg};
      }

      /* Middle-dot separators between right-side modules — matches the
         i3status-rust `separator = " · "` style. Each `custom/sepN` gets
         the same visual; the CSS selector list covers all of them. */
      #custom-sep1, #custom-sep2, #custom-sep3, #custom-sep4,
      #custom-sep5, #custom-sep6, #custom-sep7, #custom-sep8 {
        color: ${colors.comment};
        padding: 0 2px;
      }

      #custom-current-track { color: ${colors.fg}; }
      #pulseaudio { color: ${colors.aqua}; }
      #network { color: ${colors.aqua}; }
      #cpu { color: ${colors.aqua}; }
      #battery { color: ${colors.green}; }
      #battery.warning { color: ${colors.yellow}; }
      #battery.critical { color: ${colors.red}; }
      #battery.charging,
      #battery.plugged { color: ${colors.green}; }
      #clock { color: ${colors.fg}; }

      #tray > .passive { -gtk-icon-effect: dim; }
      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: ${colors.urgent};
      }
    '';
  };

  # Retry budget for the waybar.service unit. Defaults are
  # StartLimitBurst=5 / StartLimitIntervalSec=10s with RestartSec=100ms,
  # which exhausts in well under a second when the WAYLAND_DISPLAY
  # env-propagation race fires at session start. Spreading retries
  # over a 30-second window with a 2-second gap lets the unit ride out
  # 5–10s of env-import lag before systemd marks it permanently failed.
  systemd.user.services.waybar.Service.RestartSec = lib.mkForce 2;
  systemd.user.services.waybar.Unit.StartLimitBurst = lib.mkForce 10;
  systemd.user.services.waybar.Unit.StartLimitIntervalSec = lib.mkForce 30;
}
