{ config, lib, pkgs, ... }:

# Waybar replaces swaybar+i3status-rust under sway. Reason: swaybar's
# StatusNotifierItem (tray) handling only renders apps that ship embedded
# pixmap icons (Bitwarden, etc.). Apps that publish IconName (kdeconnect,
# blueman, transmission, cryptomator, …) render as the broken-icon
# placeholder. Waybar handles SNI properly.
#
# Installed unconditionally — the systemd user service is tied to
# sway-session.target, so under the i3 (X11) pick it stays inert
# (sway-session.target never starts).
let
  colors = config.personal.theming.colors;
  currentTrack = "${pkgs.my.scripts.current-track}/bin/current-track";
  bluetoothBattery = "${pkgs.my.scripts.bluetooth-battery}/bin/bluetooth-battery";
  dunstToggle = "${pkgs.my.scripts.i3dunst-toggle}/bin/i3dunst-toggle";
  playerctl = "${pkgs.playerctl}/bin/playerctl --player=spotify";
  dunstctl = "${pkgs.dunst}/bin/dunstctl";
  pavucontrol = "${pkgs.pavucontrol}/bin/pavucontrol";
  pactl = "${pkgs.pulseaudio}/bin/pactl";

  # df-based root-fs usage so the bar matches `df` exactly: used / usable
  # (excludes the ext4 root-reserved blocks). Waybar's built-in disk
  # module reports used/total instead, which reads ~5% lower. Custom
  # modules don't apply `states` from `percentage`, so the script emits
  # the warning/critical class itself.
  diskUsage = pkgs.writeShellScript "waybar-disk-usage" ''
    pct=$(${pkgs.coreutils}/bin/df --output=pcent / | ${pkgs.coreutils}/bin/tail --lines=1 | ${pkgs.coreutils}/bin/tr --delete --complement '0-9')
    if [ "$pct" -ge 90 ]; then class=critical; elif [ "$pct" -ge 80 ]; then class=warning; else class=normal; fi
    printf '{"text":"%s%%","percentage":%s,"class":"%s","tooltip":"Root filesystem: %s%% used (df)"}\n' "$pct" "$pct" "$class" "$pct"
  '';

  # Public egress IP, shown in the tooltip of a globe icon next to the
  # network modules. It can't go in the network module's own tooltip:
  # tooltip-format only interpolates the module's built-in placeholders
  # ({ipaddr}, {essid}, …), it can't run a script. The fetched IP is
  # cached in XDG_RUNTIME_DIR so on-click can copy it without a second
  # fetch. Fetch failure (offline, captive portal) emits empty text,
  # which hides the module — same trick as format-disconnected above.
  publicIp = pkgs.writeShellScript "waybar-public-ip" ''
    ip=$(${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 3 https://ifconfig.me/ip 2>/dev/null) \
      || ip=$(${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 3 https://icanhazip.com 2>/dev/null) \
      || { printf '{"text":""}\n'; exit 0; }
    via=$(${pkgs.iproute2}/bin/ip route get 1.1.1.1 2>/dev/null | ${pkgs.gawk}/bin/awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}')
    printf '%s\n' "$ip" > "''${XDG_RUNTIME_DIR:-/tmp}/waybar-public-ip"
    printf '{"text":"󰖟","tooltip":"Public IP: %s\\negress via %s"}\n' "$ip" "''${via:-?}"
  '';

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

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 28;
        spacing = 4;

        modules-left = [ "sway/workspaces" "sway/mode" ];
        modules-center = [ ];
        modules-right = [
          "custom/current-track" "custom/sep1"
          "pulseaudio" "custom/sep2"
          "network#ethernet" "network#wifi" "custom/public-ip" "custom/sep3"
          "cpu" "custom/sep4"
          "custom/disk" "custom/sep5"
          "battery" "custom/sep6"
          "custom/bluetooth-battery" "custom/sep7"
          "clock" "custom/sep8"
          "custom/dunst" "custom/sep9"
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
        "custom/sep9" = separator;

        "sway/workspaces" = {
          disable-scroll = true;
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

        # Two interface-pinned network modules. With no `interface`,
        # waybar auto-selects and can latch onto the VPN tunnel (tun0 /
        # tailscale0) — that was making the bar read "tun0" instead of the
        # SSID. Pinning each module to a NIC glob excludes the tunnels.
        # `format-disconnected = ""` yields empty output, which waybar
        # hides entirely (event_box hide), so the inactive link disappears
        # and only the connected one shows. Both share the `#network` CSS.
        "network#ethernet" = {
          interface = "e*";
          format-ethernet = "󰈀 {ifname}";
          format-disconnected = "";
          on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          format-ethernet-alt = "󰈀 {ifname} ↓{bandwidthDownBits} ↑{bandwidthUpBits}";
          tooltip-format-ethernet = "{ifname}\nIP: {ipaddr}/{cidr}\n↑ {bandwidthUpBits}  ↓ {bandwidthDownBits}";
          interval = 5;
        };
        "network#wifi" = {
          interface = "wl*";
          format-wifi = "󰖩 {essid}";
          format-disconnected = "";
          on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          format-wifi-alt = "󰖩 {signalStrength}% {essid} ↓{bandwidthDownBits} ↑{bandwidthUpBits}";
          tooltip-format-wifi = "{essid} ({signalStrength}%)\nIP: {ipaddr}/{cidr}\n↑ {bandwidthUpBits}  ↓ {bandwidthDownBits}";
          interval = 5;
        };

        "custom/public-ip" = {
          exec = "${publicIp}";
          return-type = "json";
          # 5-minute poll keeps the third-party lookups infrequent; a
          # VPN toggle shouldn't have to wait that out, so clicking
          # re-runs the fetch (exec-on-event default) after copying the
          # cached IP to the clipboard.
          interval = 300;
          on-click = "${pkgs.wl-clipboard}/bin/wl-copy < \"\${XDG_RUNTIME_DIR:-/tmp}/waybar-public-ip\"";
        };

        cpu = {
          interval = 5;
          format = "󰍛 {load}";
        };

        "custom/disk" = {
          # Root-filesystem usage, driven by df (see diskUsage) so the
          # percentage matches `df` rather than waybar's used/total. The
          # script emits the warning/critical class for the CSS below.
          exec = "${diskUsage}";
          return-type = "json";
          interval = 30;
          format = "󰋊 {}";
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
      #custom-public-ip,
      #cpu,
      #custom-disk,
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
      #custom-sep5, #custom-sep6, #custom-sep7, #custom-sep8,
      #custom-sep9 {
        color: ${colors.comment};
        padding: 0 2px;
      }

      #custom-current-track { color: ${colors.fg}; }
      #pulseaudio { color: ${colors.aqua}; }
      #network { color: ${colors.aqua}; }
      #custom-public-ip { color: ${colors.aqua}; }
      #cpu { color: ${colors.aqua}; }
      #custom-disk { color: ${colors.aqua}; }
      #custom-disk.warning { color: ${colors.yellow}; }
      #custom-disk.critical { color: ${colors.red}; }
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
  # Silence the battery module's log spam: waybar 0.15.0 ships a stray
  # `puts(status)` debug line (battery.cpp:689) that writes the battery
  # status ("Plugged"/"Charging") to stdout on every poll — ~30k journal
  # lines/day. Real logs go to stderr via spdlog, so dropping stdout
  # removes the noise without losing anything.
  systemd.user.services.waybar.Service.StandardOutput = lib.mkForce "null";
  systemd.user.services.waybar.Service.RestartSec = lib.mkForce 2;
  systemd.user.services.waybar.Unit.StartLimitBurst = lib.mkForce 10;
  systemd.user.services.waybar.Unit.StartLimitIntervalSec = lib.mkForce 30;
}
