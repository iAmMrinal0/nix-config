{ config, lib, pkgs, osConfig, ... }:

# Hyprland as the THIRD session-picker entry (alongside i3 and sway).
# Mirrors modules/home-manager/sway/config.nix wherever a 1:1 mapping
# exists; the deliberate divergences are the layout model (no tabbed/
# stacking workspace layout in Hyprland — groups replace tabs, see the
# keybind comments) and the env-var plumbing (no extraSessionCommands
# wrapper on the NixOS side — `env =` lines below are the equivalent).
#
# PARITY GAPS accepted by the user (2026-06-10): no workspace-wide tabbed
# default, no nested containers, no parent/child focus (Mod+a / Mod+Shift+a
# freed), no focus mode_toggle (Mod+space freed). Groups = opt-in tabs:
#   Mod+w        togglegroup (was: layout tabbed)
#   Mod+n / Mod+m  prev/next tab in group (changegroupactive b/f)
#   Mod+Shift+w  moveoutofgroup
# SwayFX remains one logout away when real tabs are needed.
let
  theme = config.personal.theming.colors;
  lock = "${pkgs.my.scripts.swaylock-custom}/bin/swaylock-custom";
  shutdownMenu = ''${pkgs.rofi}/bin/rofi -show power-menu -modi "power-menu:${pkgs.rofi-power-menu}/bin/rofi-power-menu"'';
  rofiTailscaleAccount = "${pkgs.my.scripts.rofi-tailscale-account}/bin/rofi-tailscale-account";
  rofiTailscaleExitNode = "${pkgs.my.scripts.rofi-tailscale-exit-node}/bin/rofi-tailscale-exit-node";
  rofiKanshi = "${pkgs.my.scripts.rofi-kanshi}/bin/rofi-kanshi";
  wallpaper = ../common/wallpapers/nix-glow-black.png;

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  # swayidle works under any compositor speaking ext-idle-notify (Hyprland
  # does); swaylock-custom likewise (ext-session-lock). Same timeouts as
  # sway's swayidleCmd; only the output-power commands change from swaymsg
  # to hyprctl. Decision "reuse swayidle/swaylock vs hypridle/hyprlock"
  # resolved: reuse — one lock/idle stack, identical look on both sessions.
  swayidleCmd = ''${pkgs.swayidle}/bin/swayidle -w timeout 300 ${lock} timeout 600 "${hyprctl} dispatch dpms off" resume "${hyprctl} dispatch dpms on" before-sleep ${lock} lock ${lock}'';

  # SNI registration-race helper, copied verbatim from sway/config.nix
  # (see the long comment there for the watcher/host two-step rationale).
  # Keep the two copies in sync.
  sniWait = cmd: ''
    ${pkgs.bash}/bin/bash -c '${pkgs.glib.bin}/bin/gdbus wait --session --timeout 30 org.kde.StatusNotifierWatcher; for i in $(seq 1 150); do reply=$(${pkgs.glib.bin}/bin/gdbus call --session --dest org.kde.StatusNotifierWatcher --object-path /StatusNotifierWatcher --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered 2>/dev/null); case "$reply" in *true*) break;; esac; sleep 0.2; done; exec ${cmd}'
  '';

  # HM's hyprland systemd integration stop+starts hyprland-session.target at
  # COMPOSITOR STARTUP but (unlike HM sway's `swaymsg subscribe shutdown`
  # pattern) stops nothing at compositor EXIT — the target would stay active
  # after logout, waybar/kanshi would crash on the dead Wayland socket,
  # systemd would restart them against the STALE WAYLAND_DISPLAY left in the
  # user-manager env (dbus-update-activation-environment only ever adds),
  # and they'd burn into start-limit-hit, poisoning the next login (gotcha
  # #2 in MULTI_SESSION_HANDOFF.md). This watcher blocks on Hyprland's
  # socket2 event socket — it closes (and its directory is removed) when the
  # compositor exits — then stops the target so waybar/kanshi stop cleanly
  # via their PartOf= binding. The `while -S` loop retries a transiently
  # dropped connection while the socket still exists, so a socat hiccup
  # can't stop the target mid-session.
  sessionTargetWatcher = ''
    ${pkgs.bash}/bin/bash -c 'sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"; while [ -S "$sock" ]; do ${pkgs.socat}/bin/socat -u UNIX-CONNECT:"$sock" /dev/null || sleep 1; done; ${pkgs.systemd}/bin/systemctl --user stop hyprland-session.target'
  '';

  # i3 parity for Mod+Shift+left/right inside a tabbed group: i3's
  # `move left/right` REORDERS the tabs within the container and only
  # moves the window out at the edge. Hyprland splits these into two
  # dispatchers — movegroupwindow (reorder within group) and
  # movewindoworgroup (leave/join/plain move) — so this helper picks by
  # the active window's position in its group: grouped and not at the
  # edge → reorder; at the edge or ungrouped → movewindoworgroup.
  # Addresses are compared 0x-stripped (hyprctl JSON is inconsistent
  # about the prefix between fields). Any lookup failure falls through
  # to movewindoworgroup, the pre-helper behavior.
  groupAwareMove = pkgs.writeShellScript "hypr-group-aware-move" ''
    dir="$1"
    aw=$(${hyprctl} -j activewindow)
    addr=$(${pkgs.jq}/bin/jq -r '.address' <<< "$aw")
    addr=''${addr#0x}
    mapfile -t grouped < <(${pkgs.jq}/bin/jq -r '.grouped[]' <<< "$aw")
    n=''${#grouped[@]}
    if (( n > 1 )); then
      idx=-1
      i=0
      for g in "''${grouped[@]}"; do
        [[ "''${g#0x}" == "$addr" ]] && idx=$i
        i=$((i + 1))
      done
      if [[ "$dir" == "l" && $idx -gt 0 ]]; then
        exec ${hyprctl} dispatch movegroupwindow b
      elif [[ "$dir" == "r" && $idx -ge 0 && $idx -lt $((n - 1)) ]]; then
        exec ${hyprctl} dispatch movegroupwindow f
      fi
    fi
    exec ${hyprctl} dispatch movewindoworgroup "$dir"
  '';

  fonts = {
    names = [ "Source Code Pro" "Symbols Nerd Font Mono" ];
    size = 10.8;
  };
  workspaceNumbers = config.personal.workspaces.numbered;
  workspaceItems = config.personal.workspaces.items;
  numbers = map toString (lib.range 1 (lib.length workspaceNumbers));
  # Hyprland workspaces stay NUMERIC (dispatchers use the number; the bar
  # shows the i3/sway-style display name via the defaultName workspace rule
  # below). Resolve a workspace key to its number for windowrules/binds.
  wsNum = key:
    toString (1 + lib.lists.findFirstIndex (w: w.key == key)
      (throw "unknown workspace key ${key}") workspaceItems);
  # Hyprland color syntax: rgb(RRGGBB) / rgba(RRGGBBAA), no leading '#'.
  rgb = c: "rgb(${lib.removePrefix "#" c})";
in {
  wayland.windowManager.hyprland = {
    enable = true;
    # One-binary rule (gotcha #1 in MULTI_SESSION_HANDOFF.md): the NixOS
    # `programs.hyprland` module owns the binary — it installs the package
    # system-wide plus the cap_sys_nice security wrapper that the session
    # .desktop resolves via /run/wrappers/bin. Letting HM install a second
    # hyprland into the per-user profile would shadow that wrapper in PATH.
    # Same mordor carve-out as sway's package: with registerSession=false
    # there is no NixOS programs.hyprland, so HM installs the binary —
    # that's what makes the pre-cutover TTY dock test possible at all.
    # Unlike sway's vars-less HM binary, this one is NOT degraded: the
    # session env lives in the env= lines of this very config. Flipping
    # registerSession nulls it again and the NixOS wrapper takes over.
    package =
      if osConfig.modules.wayland.registerSession then null else pkgs.hyprland;
    # Portals are owned by the NixOS module too (programs.hyprland wires
    # xdg-desktop-portal-hyprland + the package's portals.conf routing).
    portalPackage = null;
    # HM ≥ 26.05 state-version defaults flipped to the new Lua config
    # format; pin the classic hyprlang format explicitly so a stateVersion
    # bump can't silently change what file gets generated.
    configType = "hyprlang";
    # systemd integration (default true, kept explicit): imports
    # WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE/etc. into the user
    # manager, then stop+starts hyprland-session.target — the per-WM
    # target waybar/kanshi hang off (gotcha #2: never
    # graphical-session.target, it's sticky across WM switches).
    systemd.enable = true;

    settings = {
      "$mod" = "SUPER";

      # Wayland-only session env. MIRRORS programs.sway.extraSessionCommands
      # in modules/nixos/wayland-session.nix — keep the two lists in sync.
      # programs.hyprland has no extraSessionCommands equivalent; `env =`
      # lines are processed at config load (before exec-once, before any
      # client spawns) and are inherited by everything Hyprland execs, which
      # is the same scope the sway wrapper gives. Kept OUT of
      # environment.sessionVariables for the same reason as sway's:
      # system-wide they would break Qt/Electron under the i3 (X11) pick
      # from the same generation.
      env = [
        "NIXOS_OZONE_WL,1"
        "MOZ_ENABLE_WAYLAND,1"
        "QT_QPA_PLATFORM,wayland"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "SDL_VIDEODRIVER,wayland"
        "_JAVA_AWT_WM_NONREPARENTING,1"
        # env parsing splits on the FIRST comma only; the comma in the
        # value survives intact.
        "GDK_BACKEND,wayland,x11"
        "QT_QUICK_CONTROLS_STYLE,org.kde.desktop"
      ];

      general = {
        gaps_in = 8;
        gaps_out = 4;
        # sway runs border 0 / no titlebars; same here.
        border_size = 0;
        layout = "dwindle";
      };

      dwindle = {
        # Keep manual split orientation (Mod+e togglesplit, Mod+minus/bar
        # preselect) sticky across window closes instead of re-deriving
        # from aspect ratio every time.
        preserve_split = true;
      };

      group = {
        # auto_group (default true) makes windows opened while a group is
        # focused join it as new tabs — the closest behavior to i3's tabbed
        # containers. The groupbar is the tab bar.
        #
        # Tabs-by-default companion (see the `group set` windowrule below):
        # a window moved to another workspace with Mod+Shift+N arrives
        # ungrouped (the group rule is a static open-time effect); this
        # merges it into the destination workspace's solitary group instead,
        # like i3 moving into the tabbed container.
        group_on_movetoworkspace = true;
        groupbar = {
          enabled = true;
          font_family = lib.head fonts.names;
          font_size = 11;
          # `gradients` = the full per-tab background rectangles — the
          # sway/swayfx titlebar look (colors below mirror sway's focused/
          # unfocused titlebars). With it off only a 3px indicator line is
          # drawn. One JOINT bar fused to the window, sway-style: zero gap
          # between tabs (gaps_in) and between bar and window (gaps_out +
          # keep_upper_gap), and gradient_round_only_edges=true rounds only
          # the OUTER corners of the whole bar — tabs meet each other
          # flush, active/inactive shown purely by background color. The
          # separate indicator line is hidden, like sway.
          gradients = true;
          height = 20;
          gaps_in = 0;
          gaps_out = 0;
          keep_upper_gap = false;
          # Bar and window CANNOT round as one shape (their roundings are
          # independent in the renderer, and bar rounding hits its bottom
          # corners too) — so for a truly seamless bar+window card the bar
          # is square and the `rounding 0, match:group 1` windowrule below
          # squares grouped windows to meet it. Bump gradient_rounding
          # back up (round_only_edges keeps it to the bar's outer tabs)
          # if you ever drop that rule.
          gradient_rounding = 0;
          gradient_round_only_edges = true;
          indicator_height = 0;
          "col.active" = rgb theme.bg0;
          "col.inactive" = rgb theme.bg2;
          text_color = rgb theme.fgBright;
          text_color_inactive = rgb theme.fgMuted;
        };
      };

      decoration = {
        # Native equivalents of the SwayFX extraConfig block (corner_radius
        # 15 / shadows / default_dim_inactive 0.15 / blur off) — values
        # mirror sway/config.nix, which in turn mirrors picom on i3.
        rounding = 15;
        dim_inactive = true;
        dim_strength = 0.15;
        blur.enabled = false;
        shadow = {
          enabled = true;
          range = 5;
          render_power = 3;
          color = "rgba(00000080)";
          offset = "0 0";
        };
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      binds = {
        # movefocus is spatial by default, so inside a group (tabs occupy
        # one spot) Mod+h/l jumps OUT of the group instead of to the next
        # tab. groupfirst = cycle the group's tabs first, leave the group
        # only past the edge — i3/sway `focus left/right` in a tabbed
        # container.
        movefocus_cycles_groupfirst = true;
      };

      input = {
        kb_layout = "us,se";
        kb_options = "grp:switch";
        numlock_by_default = true;
      };

      # Fallback only — kanshi owns output configuration (WantedBy
      # hyprland-session.target, see modules/home-manager/kanshi.nix).
      monitor = [ ",preferred,auto,1" ];

      # Numeric workspaces carry the i3/sway display names via defaultName,
      # so waybar's hyprland/workspaces module renders the same labels as
      # sway/workspaces does.
      workspace =
        lib.zipListsWith (n: full: "${n}, defaultName:${full}") numbers
        workspaceNumbers;

      # sway `assigns` + window commands. Hyprland matches `match:class`
      # against the Wayland app_id AND the XWayland class with one matcher,
      # so the dual app_id/class lists collapse. `silent` = don't switch
      # focus, same as i3/sway assign semantics. Spotify caveat carried over
      # from i3: it sets its class late under XWayland, but with
      # NIXOS_OZONE_WL it runs native Wayland and sets app_id at map, so the
      # rule fires. No `urgent enable` equivalent exists; apps that request
      # attention via xdg-activation (the Electron set below does) still
      # flash in waybar's workspace module.
      #
      # SYNTAX (Hyprland 0.55 rewrote window rules; hyprlang `windowrule`
      # now goes through a legacy translator, src/config/legacy/
      # ConfigManager.cpp handleWindowrule): comma-separated tokens, each
      # token is `<effect> <value>` or `match:<prop> <value>` — every token
      # NEEDS a space+value, so flag effects are spelled `float 1`, and the
      # old `class:^regex$` prop form is rejected with "invalid field type".
      # `move`/`size` values are now muParser expressions (no internal
      # spaces; monitor_w/monitor_h/window_w/window_h/cursor_x/cursor_y) —
      # percent forms like `70%` are gone.
      windowrule = [
        # Tabs-by-default: every tiled window opens as a (1-tab) group, and
        # windows opened while a group is focused join it as tabs
        # (group:auto_group) — Hyprland's closest equivalent of i3's
        # `workspace_layout tabbed`. Floating windows (PiP, dialogs) are
        # unaffected: groups are tiled-only. Escape hatches: Mod+w
        # ungroups, Mod+Shift+w pops the focused tab out, Mod+Shift+dir
        # (movewindoworgroup) moves tabs out/in directionally.
        "group set, match:class .*"
        # Seamless tab bar: grouped windows drop their corner rounding so
        # the (square) groupbar and the window meet as one unbroken card —
        # the swayfx unified-rounded-container look is impossible here
        # (window and bar rounding are independent in the renderer), so
        # square-when-tabbed is the no-breaks option. Both `rounding`
        # (effect) and `group` (match) are dynamic: leaving the group
        # restores the decoration.rounding 15.
        "rounding 0, match:group 1"
        "workspace ${wsNum "code"} silent, match:class ^[Cc]ode$"
        "workspace ${wsNum "music"} silent, match:class ^[Vv]lc$"
        "workspace ${wsNum "music"} silent, match:class ^[Ss]potify$"
        "workspace ${wsNum "avoid"} silent, match:class ^(Slack|discord|Element)$"
        # Firefox/Chrome Picture-in-Picture: float + pin (sway's sticky) +
        # small bottom-right corner, positioned relative to monitor size so
        # it lands right on every output — mirrors the sway window command.
        "float 1, match:title ^(Picture-in-Picture)$"
        "pin 1, match:title ^(Picture-in-Picture)$"
        "size 480 270, match:title ^(Picture-in-Picture)$"
        "move monitor_w*0.7 monitor_h*0.7, match:title ^(Picture-in-Picture)$"
        # Thunar's secondary dialogs don't set the dialog hint; float them
        # by title, same list as sway/config.nix.
        "float 1, match:class ^([Tt]hunar)$, match:title ^(?i)(rename|copy|copying|move|moving|properties|confirm|file operation).*"
      ];

      exec-once = [
        # Cross-WM hygiene, mirroring sway's startup: stop i3-only units
        # that outlive an i3 session (no-op when not running) and scrub the
        # stale sway IPC socket var so waybar's sway modules don't chase a
        # dead socket. WAYLAND_DISPLAY is NOT unset here — HM's systemd
        # integration just imported the fresh one.
        "${pkgs.systemd}/bin/systemctl --user stop redshift.service xss-lock.service picom.service"
        "${pkgs.systemd}/bin/systemctl --user unset-environment SWAYSOCK"
        sessionTargetWatcher
        "${pkgs.swaybg}/bin/swaybg -i ${wallpaper} -m fill"
        swayidleCmd
        # Tray apps via compositor exec, NOT systemd — same three reasons
        # as the sway startup comment (tray.target deadlock, env race,
        # no singleton need). sniWait + QT_QPA_PLATFORM=xcb choices are
        # explained app-by-app in sway/config.nix; keep the lists in sync.
        "${pkgs.blueman}/bin/blueman-applet"
        (sniWait "${pkgs.coreutils}/bin/env QT_QPA_PLATFORM=xcb ${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator")
        "${pkgs.udiskie}/bin/udiskie -t"
        "${pkgs.cbatticon}/bin/cbatticon -c '${pkgs.libnotify}/bin/notify-send \"Battery critically low!\"' -l 20 -r 10"
        "${pkgs.cryptomator}/bin/cryptomator"
        (sniWait "${pkgs.gammastep}/bin/gammastep-indicator")
        (sniWait "${pkgs.coreutils}/bin/env QT_QPA_PLATFORM=xcb ${pkgs.transmission_4-qt}/bin/transmission-qt --minimized")
        "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ 25%"
        "${pkgs.bitwarden-desktop}/bin/bitwarden"
      ];

      bind = [
        # exec binds (1:1 with sway)
        "$mod CTRL, l, exec, ${shutdownMenu}"
        "$mod CTRL ALT, p, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        "$mod CTRL ALT, Right, exec, ${pkgs.playerctl}/bin/playerctl next"
        "$mod CTRL ALT, Left, exec, ${pkgs.playerctl}/bin/playerctl previous"
        "$mod CTRL ALT, Up, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%"
        "$mod CTRL ALT, Down, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%"
        "$mod CTRL ALT, m, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
        "$mod, Return, exec, ${pkgs.kitty}/bin/kitty"
        "$mod SHIFT, Return, exec, ${pkgs.kitty}/bin/kitty tmux"
        # Mod+g (sway-easyfocus) not ported: it speaks sway IPC only.
        "$mod CTRL, k, exec, ${pkgs.rofi-rbw}/bin/rofi-rbw"
        "$mod CTRL, p, exec, ${pkgs.rofimoji}/bin/rofimoji --action copy"
        ''$mod, t, exec, ${pkgs.libnotify}/bin/notify-send -t 5000 "`date +%H:%M`" "`date +%A` `date +%d` `date +%B` `date +%Y` - Week `date +%V`"''
        "$mod SHIFT, c, exec, ${hyprctl} reload"
        "$mod, d, exec, ${pkgs.rofi}/bin/rofi -show run"
        "$mod CTRL, d, exec, ${pkgs.rofi}/bin/rofi -show drun"
        "$mod CTRL, w, exec, ${pkgs.rofi}/bin/rofi -show window"
        "$mod CTRL, s, exec, ${pkgs.rofi}/bin/rofi -show ssh"
        "$mod, p, exec, ${rofiKanshi}"
        "$mod SHIFT, e, exec, ${rofiTailscaleExitNode}"
        "$mod SHIFT, t, exec, ${rofiTailscaleAccount}"

        # focus / move (h/j/k/l + arrows)
        "$mod, h, movefocus, l"
        "$mod, j, movefocus, d"
        "$mod, k, movefocus, u"
        "$mod, l, movefocus, r"
        "$mod, Left, movefocus, l"
        "$mod, Down, movefocus, d"
        "$mod, Up, movefocus, u"
        "$mod, Right, movefocus, r"
        # Horizontal moves go through groupAwareMove (see let): reorder
        # tabs inside a group, movewindoworgroup otherwise — i3 `move
        # left/right` semantics. movewindoworgroup (not movewindow) so
        # moving toward a group joins it as a tab; mouse equivalent:
        # Mod+drag onto the groupbar (group:drag_into_group, on by
        # default). Vertical moves stay native: tabs are horizontal, so
        # u/d always means leave/join/move like i3.
        "$mod SHIFT, h, exec, ${groupAwareMove} l"
        "$mod SHIFT, j, movewindoworgroup, d"
        "$mod SHIFT, k, movewindoworgroup, u"
        "$mod SHIFT, l, exec, ${groupAwareMove} r"
        "$mod SHIFT, Left, exec, ${groupAwareMove} l"
        "$mod SHIFT, Down, movewindoworgroup, d"
        "$mod SHIFT, Up, movewindoworgroup, u"
        "$mod SHIFT, Right, exec, ${groupAwareMove} r"

        # layout: groups replace tabbed/stacking (see header comment)
        "$mod, w, togglegroup"
        "$mod, n, changegroupactive, b"
        "$mod, m, changegroupactive, f"
        "$mod SHIFT, w, moveoutofgroup"
        "$mod, e, layoutmsg, togglesplit"
        "$mod, s, layoutmsg, swapsplit"
        # sway split v/h (where the NEXT window opens) → dwindle preselect.
        # `bar` is a shifted keysym (Shift+backslash on us): sway lets the
        # implicit Shift through, Hyprland needs it listed in the mods.
        "$mod, minus, layoutmsg, preselect d"
        "$mod SHIFT, bar, layoutmsg, preselect r"

        "$mod, f, fullscreen, 0"
        "$mod, Tab, workspace, previous"
        "$mod SHIFT, q, killactive"
        "$mod SHIFT, space, togglefloating"
        # sway scratchpad → special workspace: Mod+q stashes, Mod+x toggles.
        # Difference from i3/sway: the special workspace shows ALL stashed
        # windows at once instead of cycling them one `scratchpad show` at
        # a time.
        "$mod, q, movetoworkspacesilent, special:scratch"
        "$mod, x, togglespecialworkspace, scratch"
        # sway `[urgent=latest] focus`
        "$mod SHIFT, x, focusurgentorlast"
        "$mod SHIFT, m, exec, ${pkgs.pulseaudio}/bin/pactl set-source-mute 1 toggle"

        # move current workspace between outputs
        "$mod CTRL, Down, movecurrentworkspacetomonitor, d"
        "$mod CTRL, Up, movecurrentworkspacetomonitor, u"
        "$mod CTRL, Left, movecurrentworkspacetomonitor, l"
        "$mod CTRL, Right, movecurrentworkspacetomonitor, r"

        "$mod, r, submap, resize"

        # media/function keys + utilities (sway's appendExecToCommand set)
        ", XF86AudioRaiseVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%"
        ", XF86AudioLowerVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%"
        ", XF86AudioMute, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
        ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
        ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"
        ", XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 10%-"
        ", XF86AudioMicMute, exec, ${pkgs.pulseaudio}/bin/pactl set-source-mute 0 toggle"
        # flameshot grabs frames via xdg-desktop-portal-hyprland here (the
        # wlr portal serves sway; routing is per-XDG_CURRENT_DESKTOP).
        # NOTE: this block mirrors sway's appendExecToCommand set, which is
        # NOT Mod-prefixed (unlike everything above).
        ", Print, exec, ${pkgs.flameshot}/bin/flameshot gui"
        "CTRL ALT, c, exec, ${pkgs.rofi}/bin/rofi -show calc -modi calc -no-show-match -no-sort"
        "CTRL ALT, l, exec, ${lock}"
        "CTRL, space, exec, ${pkgs.dunst}/bin/dunstctl close"
        "CTRL SHIFT, space, exec, ${pkgs.dunst}/bin/dunstctl close-all"
        "CTRL, grave, exec, ${pkgs.dunst}/bin/dunstctl history-pop"
      ]
      # workspace switching / moving; movetoworkspace follows the window,
      # matching sway's "move container to workspace N; workspace N".
      ++ lib.concatMap (n: [
        "$mod, ${n}, workspace, ${n}"
        "$mod SHIFT, ${n}, movetoworkspace, ${n}"
      ]) numbers;

      # Mod+drag to move/resize floating windows (sway floating_modifier).
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };

    # Mirrors sway's resize mode bindings (binde = repeat while held).
    submaps.resize = {
      settings = {
        binde = [
          ", h, resizeactive, -10 0"
          ", j, resizeactive, 0 -10"
          ", k, resizeactive, 0 10"
          ", l, resizeactive, 10 0"
          ", Left, resizeactive, -10 0"
          ", Down, resizeactive, 0 10"
          ", Up, resizeactive, 0 -10"
          ", Right, resizeactive, 10 0"
        ];
        bind = [
          ", Return, submap, reset"
          ", escape, submap, reset"
        ];
      };
    };
  };
}
