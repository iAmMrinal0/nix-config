{ config, lib, pkgs, inputs, ... }:

let
  theme = config.personal.theming.colors;
  lock = "${pkgs.scripts.i3lock-custom}/bin/i3lock-custom";
  shutdownMenu = ''${pkgs.rofi}/bin/rofi -show power-menu -modi "power-menu:${pkgs.rofi-power-menu}/bin/rofi-power-menu"'';
  rofiAutorandr = "${pkgs.scripts.rofi-autorandr}/bin/rofi-autorandr";
  rofiTailscaleAccount = "${pkgs.scripts.rofi-tailscale-account}/bin/rofi-tailscale-account";
  rofiTailscaleExitNode = "${pkgs.scripts.rofi-tailscale-exit-node}/bin/rofi-tailscale-exit-node";

  fontSize = 10.8;
  workspaces = [
    " term"
    " code"
    " web"
    "♪ music"
    " avoid"
    "scratch"
    "scratch"
    "scratch"
    " bg"
  ];
  fonts = {
    names = [ "Source Code Pro" "Symbols Nerd Font" ];
    style = "Medium";
    size = fontSize;
  };
  numbers = map toString (lib.range 1 9);
  workspaceNumbers = lib.zipListsWith (x: y: x + " " + y) numbers workspaces;
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
        "\"${lib.elemAt workspaceNumbers 1}\"" = [{ class = "^Code$"; }];
        "\"${lib.elemAt workspaceNumbers 3}\"" = [{ class = "Vlc"; }];
        "\"${lib.elemAt workspaceNumbers 4}\"" = [
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
            border = theme.bg0;
            background = theme.bg0;
            text = theme.urgent;
          };
        };
      }];
      window = {
        border = 0;
        titlebar = false;
        hideEdgeBorders = "both";
        commands = [
          {
            command = ''move to workspace "${lib.elemAt workspaceNumbers 3}"'';
            criteria = { class = "Spotify"; };
          }
          {
            command = "sticky enable";
            criteria = { title = "Picture-in-Picture"; };
          }
        ];
      };
      gaps = {
        inner = 8;
        outer = 4;
        smartGaps = true;
        smartBorders = "on";
      };
      startup = [
        { command = "${pkgs.xorg.xset}/bin/xset -b"; }
        {
          command = "${pkgs.cryptomator}/bin/cryptomator &";
        }
        {
          # Standby after 5 minutes, Suspend after 10 minutes, Off after 15 minutes
          command = "${pkgs.xorg.xset}/bin/xset dpms 300 600 900";
        }
        {
          # Trigger X screensaver at 5 minutes idle; xss-lock catches the event
          # and runs the lock command. Honors org.freedesktop.ScreenSaver
          # inhibits, so videos (mpv/Firefox/Chromium) won't trigger a lock.
          command = "${pkgs.xorg.xset}/bin/xset s 300 300";
        }
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
          border = theme.bg2;
          background = theme.bg2;
          text = theme.fgMuted;
          indicator = theme.bg2;
          childBorder = theme.bg2;
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
          text = theme.fg;
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
          exec ${pkgs.libnotify}/bin/notify-send -t 5000 "`date +%H:%M`" "`date +%A` `date +%d` `date +%B` `date +%Y` - Week `date +%U`"'';
        "a" = "focus child";
        "Control+Down" = "move workspace to output down";
        "Control+Up" = "move workspace to output up";
        "Control+Left" = "move workspace to output left";
        "Control+Right" = "move workspace to output right";
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
          "exec ${pkgs.pulseaudio}/bin/pactl set-source-mute 1 toggle";
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

        "XF86MonBrightnessUp" = "${pkgs.light}/bin/light -A 10";
        "XF86MonBrightnessDown" = "${pkgs.light}/bin/light -U 10";

        "XF86AudioMicMute" =
          "${pkgs.pulseaudio}/bin/pactl set-source-mute 0 toggle";

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
