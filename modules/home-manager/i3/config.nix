{ config, lib, pkgs, inputs, ... }:

let
  theme = config.personal.theming.colors;
  lock = "${pkgs.my.scripts.i3lock-custom}/bin/i3lock-custom";
  shutdownMenu = ''${pkgs.rofi}/bin/rofi -show power-menu -modi "power-menu:${pkgs.rofi-power-menu}/bin/rofi-power-menu"'';
  rofiAutorandr = "${pkgs.my.scripts.rofi-autorandr}/bin/rofi-autorandr";
  rofiTailscaleAccount = "${pkgs.my.scripts.rofi-tailscale-account}/bin/rofi-tailscale-account";
  rofiTailscaleExitNode = "${pkgs.my.scripts.rofi-tailscale-exit-node}/bin/rofi-tailscale-exit-node";

  # i3's `move workspace to output <dir>` doesn't trigger mouse_warping, so
  # the cursor stays put. Warp it onto the focused workspace's rect after
  # the move — works for any monitor count or layout.
  warpToFocused = pkgs.writeShellScript "i3-warp-to-focused" ''
    ${pkgs.i3}/bin/i3-msg -t get_workspaces \
      | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | "\(.rect.x) \(.rect.y)"' \
      | xargs ${pkgs.xdotool}/bin/xdotool mousemove
  '';

  fontSize = 10.8;
  fonts = {
    names = [
      "Source Code Pro"
      # FA Free has glyphs that Symbols Nerd Font is missing (e.g.
      # volume-xmark at U+F6A9, used by i3status-rust `awesome6` icons).
      # Listed before NF so FA wins for overlapping codepoints.
      "Font Awesome 7 Free"
      "Symbols Nerd Font Mono"
    ];
    style = "Medium";
    size = fontSize;
  };
  workspaceNumbers = config.personal.workspaces.numbered;
  workspacesByKey = config.personal.workspaces.byKey;
  numbers = map toString (lib.range 1 (lib.length workspaceNumbers));
  useWithModifier = mod:
    lib.mapAttrs' (k: v: lib.nameValuePair (mod + "+" + k) v);
  appendExecToCommand = lib.mapAttrs' (k: v: lib.nameValuePair k ("exec " + v));
in {
  xsession.windowManager.i3 = {
    enable = true;
    extraConfig = ''
      title_align center
    '';
    config = rec {
      inherit fonts;
      modifier = "Mod4";
      terminal = "kitty";
      workspaceLayout = "tabbed";
      assigns = {
        "\"${workspacesByKey.code}\"" = [{ class = "^Code$"; }];
        "\"${workspacesByKey.music}\"" = [{ class = "Vlc"; }];
        "\"${workspacesByKey.avoid}\"" = [
          { class = "Slack"; }
          { class = "discord"; }
          { class = "Element"; }
        ];
      };
      bars = [{
        inherit fonts;
        position = "top";
        trayOutput = "primary";
        statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs $HOME/.config/i3status-rust/config-default.toml";
        colors = {
          background = theme.bg0;
          statusline = theme.fg;
          separator = theme.comment;
          inactiveWorkspace = {
            border = theme.bg0;
            background = theme.bg0;
            text = theme.comment;
          };
          activeWorkspace = {
            border = theme.bg0;
            background = theme.bg0;
            text = theme.comment;
          };
          focusedWorkspace = {
            border = theme.bg0;
            background = theme.bg0;
            text = theme.fgBright;
          };
          urgentWorkspace = {
            border = theme.urgent;
            background = theme.urgent;
            text = theme.fgBright;
          };
        };
      }];
      window = {
        border = 0;
        titlebar = false;
        hideEdgeBorders = "both";
        commands = [
          {
            command = ''move to workspace "${workspacesByKey.music}"'';
            criteria = { class = "Spotify"; };
          }
          {
            command = "sticky enable";
            criteria = { title = "Picture-in-Picture"; };
          }
          {
            command = "floating enable, border pixel 1";
            criteria = { class = "Gsimplecal"; };
          }
        ];
      };
      gaps = {
        inner = 8;
        outer = 4;
        smartGaps = false;
        smartBorders = "on";
      };
      startup = [
        # Scrub the dead sway session's Wayland vars from the persistent
        # systemd --user env. sway imports WAYLAND_DISPLAY/SWAYSOCK via
        # dbus-update-activation-environment at its startup but nothing
        # removes them on exit, so after a sway→i3 switch the env still
        # advertises a dead wayland-1 socket — waybar/kanshi's
        # ConditionEnvironment=WAYLAND_DISPLAY then PASSES under i3, they
        # launch, die with "Bar need to run under Wayland", and burn their
        # restart budget (start-limit-hit) which can poison the NEXT sway
        # login. Unsetting here makes the condition fail cleanly under i3.
        {
          command =
            "${pkgs.systemd}/bin/systemctl --user unset-environment WAYLAND_DISPLAY SWAYSOCK";
        }
        { command = "${pkgs.xset}/bin/xset -b"; }
        {
          command = "${pkgs.cryptomator}/bin/cryptomator &";
        }
        {
          # Standby after 5 minutes, Suspend after 10 minutes, Off after 15 minutes
          command = "${pkgs.xset}/bin/xset dpms 300 600 900";
        }
        {
          # Trigger X screensaver at 5 minutes idle; xss-lock catches the event
          # and runs the lock command. Honors org.freedesktop.ScreenSaver
          # inhibits, so videos (mpv/Firefox/Chromium) won't trigger a lock.
          command = "${pkgs.xset}/bin/xset s 300 300";
        }
        # Per-WM units launched HERE (not via systemd autostart) so they run
        # only under i3, never sway — their WantedBy is forced empty in
        # modules/home/services.nix because graphical-session.target is shared
        # by both stacks. xss-lock catches the xset screensaver event above and
        # locks via i3lock-custom; redshift is the X11 color-temp daemon (sway
        # uses gammastep instead). Both need an X server, so they're i3-only.
        { command = "${pkgs.systemd}/bin/systemctl --user start xss-lock.service"; }
        { command = "${pkgs.systemd}/bin/systemctl --user start redshift.service"; }
        # picom: X11 compositor, i3-only (WantedBy forced empty in
        # modules/home/services.nix so it doesn't leak into sway).
        { command = "${pkgs.systemd}/bin/systemctl --user start picom.service"; }
        { command = "${pkgs.transmission_4-gtk}/bin/transmission-gtk --minimized"; }
        {
          command =
            "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
        }
        {
          command =
            "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ 25%";
        }
        {
          command = "${pkgs.numlockx}/bin/numlockx on";
        }
        { command = "${pkgs.bitwarden-desktop}/bin/bitwarden"; }
      ];
      modes = {
        resize = {
          h = "resize shrink width 10 px or 10 ppt";
          j = "resize shrink height 10 px or 10 ppt";
          k = "resize grow height 10 px or 10 ppt";
          l = "resize grow width 10 px or 10 ppt";
          Down = "resize grow height 10 px or 10 ppt";
          Left = "resize shrink width 10 px or 10 ppt";
          Right = "resize grow width 10 px or 10 ppt";
          Up = "resize shrink height 10 px or 10 ppt";
          Return = "mode default";
          Escape = "mode default";
        };
      };
      colors = {
        background = theme.bg0;

        unfocused = {
          border = theme.bg2;
          background = theme.bg2;
          text = theme.fgMuted;
          indicator = theme.bg2;
          childBorder = theme.bg2;
        };

        focusedInactive = {
          border = theme.bg0;
          background = theme.bg0;
          text = theme.fg;
          indicator = theme.bg0;
          childBorder = theme.bg0;
        };

        focused = {
          border = theme.bg0;
          background = theme.bg0;
          text = theme.fgBright;
          indicator = theme.bg0;
          childBorder = theme.bg0;
        };

        urgent = {
          border = theme.urgent;
          background = theme.urgent;
          text = theme.fgBright;
          indicator = theme.urgent;
          childBorder = theme.urgent;
        };

        placeholder = {
          border = theme.bg0;
          background = theme.bg0;
          text = theme.fg;
          indicator = theme.bg0;
          childBorder = theme.bg0;
        };
      };
      keybindings = useWithModifier modifier ({
        "Control+l" = "exec ${shutdownMenu}";
        "Control+mod1+p" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
        "Control+mod1+Right" = "exec ${pkgs.playerctl}/bin/playerctl next";
        "Control+mod1+Left" = "exec ${pkgs.playerctl}/bin/playerctl previous";
        "Control+mod1+Up" =
          "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%";
        "Control+mod1+Down" =
          "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
        "Control+mod1+m" =
          "exec ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
        "Return" = "exec ${pkgs.kitty}/bin/kitty";
        "Shift+Return" = "exec ${pkgs.kitty}/bin/kitty tmux";
        "g" = "exec ${pkgs.wmfocus}/bin/wmfocus --fill -c asdf --textcolor red";
        "Control+k" = "exec ${pkgs.rofi-rbw}/bin/rofi-rbw";
        "Control+p" = "exec ${pkgs.rofimoji}/bin/rofimoji --action copy";
        "t" = ''
          exec ${pkgs.libnotify}/bin/notify-send -t 5000 "`date +%H:%M`" "`date +%A` `date +%d` `date +%B` `date +%Y` - Week `date +%V`"'';
        "a" = "focus child";
        "Control+Down" = "move workspace to output down; exec --no-startup-id ${warpToFocused}";
        "Control+Up" = "move workspace to output up; exec --no-startup-id ${warpToFocused}";
        "Control+Left" = "move workspace to output left; exec --no-startup-id ${warpToFocused}";
        "Control+Right" = "move workspace to output right; exec --no-startup-id ${warpToFocused}";
        "Shift+c" = "reload";
        "Shift+r" = "restart";
        "d" = "exec ${pkgs.rofi}/bin/rofi -show run";
        "Control+d" = "exec i3-dmenu-desktop --dmenu 'rofi -dmenu'";
        "Control+w" = "exec ${pkgs.rofi}/bin/rofi -show window";
        "Control+s" = "exec ${pkgs.rofi}/bin/rofi -show ssh";
        "p" = "exec ${rofiAutorandr}";
        "Shift+e" = "exec ${rofiTailscaleExitNode}";
        "Shift+t" = "exec ${rofiTailscaleAccount}";
        "e" = "layout toggle stacking tabbed splith splitv";
        "f" = "fullscreen toggle";
        "Tab" = "workspace back_and_forth";
        "h" = "focus left";
        "j" = "focus down";
        "k" = "focus up";
        "l" = "focus right";
        "Left" = "focus left";
        "Down" = "focus down";
        "Up" = "focus up";
        "Right" = "focus right";
        "minus" = "split vertical";
        "bar" = "split horizontal";
        "Shift+q" = "kill";
        "r" = "mode resize";
        "Shift+a" = "focus parent";
        "q" = "move scratchpad";
        "x" = "scratchpad show";
        "Shift+h" = "move left";
        "Shift+j" = "move down";
        "Shift+k" = "move up";
        "Shift+l" = "move right";
        "Shift+Left" = "move left";
        "Shift+Down" = "move down";
        "Shift+Up" = "move up";
        "Shift+Right" = "move right";
        "Shift+space" = "floating toggle";
        "Shift+m" =
          "exec ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle";
        "s" = "layout stacking";
        "space" = "focus mode_toggle";
        "w" = "layout tabbed";
        "Shift+x" = "[urgent=latest] focus";
      } // lib.foldl (x: y: x // y) { } (lib.zipListsWith (i: n: {
        "${i}" = "workspace ${n}";
        "Shift+${i}" = "move container to workspace ${n}; workspace ${n}";
      }) numbers workspaceNumbers)) // appendExecToCommand ({
        "XF86AudioRaiseVolume" =
          "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%";
        "XF86AudioLowerVolume" =
          "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
        "XF86AudioMute" =
          "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";

        "XF86AudioPlay" = "${pkgs.playerctl}/bin/playerctl play-pause";
        "XF86AudioNext" = "${pkgs.playerctl}/bin/playerctl next";
        "XF86AudioPrev" = "${pkgs.playerctl}/bin/playerctl previous";

        # pkgs.light was removed in 26.05; use brightnessctl (backed by
        # the udev rules set in base.nix).
        "XF86MonBrightnessUp" = "${pkgs.brightnessctl}/bin/brightnessctl set +10%";
        "XF86MonBrightnessDown" = "${pkgs.brightnessctl}/bin/brightnessctl set 10%-";

        "XF86AudioMicMute" =
          "${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle";

        "Print" = "${pkgs.gnome-screenshot}/bin/gnome-screenshot -i";

        "Control+mod1+c" =
          "${pkgs.rofi}/bin/rofi -show calc -modi calc -no-show-match -no-sort";

        "Control+mod1+l" = "${lock}";

        # dunst shortcuts
        "Control+space" = "${pkgs.dunst}/bin/dunstctl close";
        "Control+Shift+space" = "${pkgs.dunst}/bin/dunstctl close-all";
        "Control+grave" = "${pkgs.dunst}/bin/dunstctl history-pop";
      });
    };
  };
}
