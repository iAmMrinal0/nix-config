{ config, lib, pkgs, inputs, osConfig, ... }:

let
  theme = config.personal.theming.colors;
  lock = "${pkgs.my.scripts.swaylock-custom}/bin/swaylock-custom";
  shutdownMenu = ''${pkgs.rofi}/bin/rofi -show power-menu -modi "power-menu:${pkgs.rofi-power-menu}/bin/rofi-power-menu"'';
  rofiTailscaleAccount = "${pkgs.my.scripts.rofi-tailscale-account}/bin/rofi-tailscale-account";
  rofiTailscaleExitNode = "${pkgs.my.scripts.rofi-tailscale-exit-node}/bin/rofi-tailscale-exit-node";
  rofiKanshi = "${pkgs.my.scripts.rofi-kanshi}/bin/rofi-kanshi";
  micMuteToggle = "${pkgs.my.scripts.mic-mute-toggle}/bin/mic-mute-toggle";
  wallpaper = ../common/wallpapers/nix-glow-black.png;

  swaymsg = "${pkgs.sway}/bin/swaymsg";
  # DPMS wake helper for the resume hook. A wildcard `output * power on`
  # silently fails for evdi outputs: the all-outputs atomic commit gets
  # rejected (cf. "Atomic commit failed" for DVI connectors in the logs)
  # and the dock monitors stay power=false until a modeset — which is why
  # restarting kanshi "fixed" it. Per-output commands work, but two evdi
  # outputs kicked back-to-back can still race each other's modeset, so
  # retry whatever is still off until everything reports power=true
  # (verified live 2026-06-12: converges after at most one retry).
  #
  # The power cycle can also scramble output positions (the evdi
  # re-enable comes back with default placement, not the profile's), and
  # kanshi only re-applies profiles on connect/disconnect events — so
  # after everything is powered on, kanshictl reload re-applies the
  # matched profile. That re-apply is a SECOND modeset (a visible blink on
  # wake, unlike X11's DPMS which just re-signals a fixed layout), and the
  # position-scramble it fixes can only matter with more than one output —
  # so we gate the reload on >1 active output. A single display skips it and
  # wakes clean. `|| true`: don't fail the hook if kanshi is down.
  wakeOutputs = pkgs.writeShellScript "sway-wake-outputs" ''
    for i in 1 2 3 4 5; do
      off=$(${swaymsg} -t get_outputs --raw \
        | ${pkgs.jq}/bin/jq -r '.[] | select(.power == false) | .name')
      [ -z "$off" ] && break
      for o in $off; do
        ${swaymsg} "output $o power on"
      done
      sleep 1
    done
    # Only re-apply the kanshi profile when more than one output is active
    # (the sole case evdi position-scramble can affect). On a single display
    # the reload is a gratuitous extra modeset — skipping it removes the
    # wake/unlock blink. See the comment above.
    active=$(${swaymsg} -t get_outputs --raw \
      | ${pkgs.jq}/bin/jq -r '[.[] | select(.active)] | length')
    if [ "''${active:-0}" -gt 1 ]; then
      ${pkgs.kanshi}/bin/kanshictl reload || true
    fi
  '';
  # Supervised swayidle launcher. The swayidle invocation is inlined here
  # (rather than going through services.swayidle) so the launch happens via
  # sway exec in sway's process env — see swayidle.nix for why the
  # systemd-unit path raced. Behaviour of the swayidle args:
  #   timeout 300  → lock screen
  #   timeout 600  → power outputs off; on resume, wake outputs (evdi-safe)
  #   before-sleep → lock before the system suspends
  #   lock         → lock when `loginctl lock-session` fires
  #
  # The wrapper around it fixes two consequences of the direct-exec launch
  # that bit us in the "unlock N times" cascade (see swaylock-custom):
  #   1. Captured debug log. swayidle's stdout/stderr otherwise go nowhere,
  #      so when it re-fires lock seconds after an unlock there's no record
  #      of *which* event triggered it. `-d` + redirect to
  #      $XDG_RUNTIME_DIR/swayidle.log (per-user tmpfs, 0700) records every
  #      event swayidle handles and any output-modeset errors from the
  #      power-off/resume cycle. Pairs with swaylock-custom.log to pinpoint
  #      the relock trigger. Truncated once per session at launch.
  #   2. Respawn loop. A direct sway `exec` is one-shot — if swayidle crashes
  #      (suspected: evdi output modeset during the idle power-off/resume
  #      cycle) it is never restarted and the session silently loses
  #      auto-lock. The loop restarts it; the 2s backoff stops a
  #      hard-failing swayidle from hot-looping.
  swayidleCmd = pkgs.writeShellScript "swayidle-supervised" ''
    LOG="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/swayidle.log"
    : > "$LOG"
    while true; do
      ${pkgs.coreutils}/bin/printf '%s swayidle starting\n' \
        "$(${pkgs.coreutils}/bin/date +%Y-%m-%dT%H:%M:%S.%N)" >> "$LOG"
      ${pkgs.swayidle}/bin/swayidle -d -w \
        timeout 300 ${lock} \
        timeout 600 "${swaymsg} 'output * power off'" resume ${wakeOutputs} \
        before-sleep ${lock} \
        lock ${lock} >> "$LOG" 2>&1
      rc=$?
      ${pkgs.coreutils}/bin/printf '%s swayidle exited (rc=%d), respawning in 2s\n' \
        "$(${pkgs.coreutils}/bin/date +%Y-%m-%dT%H:%M:%S.%N)" "$rc" >> "$LOG"
      ${pkgs.coreutils}/bin/sleep 2
    done
  '';

  # Tray apps that don't retry SNI registration if the watcher/host isn't
  # ready at startup. Sway exec'ing all tray apps in parallel races
  # waybar's tray module; some Qt/KF6 apps lose that race silently and
  # never show in the bar (kdeconnect-indicator, transmission-qt,
  # gammastep-indicator). Two-step wait:
  #   1. `gdbus wait` until waybar owns org.kde.StatusNotifierWatcher
  #   2. poll IsStatusNotifierHostRegistered until true (the host is the
  #      consumer of newly-registered items; if the item registers on
  #      a watcher with no host attached, some apps don't retry and the
  #      icon never appears)
  # Step 2 fixes the failure mode we saw with kdeconnect: gdbus wait
  # returned immediately because the watcher was up, but the host
  # registration lagged a few hundred ms behind, kdeconnect-indicator
  # registered into the gap, no host saw the item. Cap each step at 30s
  # so a misconfigured watcher can't hang sway exec forever.
  # Apps not wrapped here (blueman, udiskie, cbatticon, cryptomator,
  # bitwarden) already retry or use embedded pixmaps and show up reliably.
  sniWait = cmd: ''
    ${pkgs.bash}/bin/bash -c '${pkgs.glib.bin}/bin/gdbus wait --session --timeout 30 org.kde.StatusNotifierWatcher; for i in $(seq 1 150); do reply=$(${pkgs.glib.bin}/bin/gdbus call --session --dest org.kde.StatusNotifierWatcher --object-path /StatusNotifierWatcher --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered 2>/dev/null); case "$reply" in *true*) break;; esac; sleep 0.2; done; exec ${cmd}'
  '';

  fontSize = 10.8;
  fonts = {
    names = [ "Source Code Pro" "Symbols Nerd Font Mono" ];
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
  # Bind all Wayland systemd --user services (waybar, kanshi) to
  # sway-session.target instead of the HM default graphical-session.target.
  # WHY: with the login picker, one boot can run i3 then sway (or vice-versa)
  # and the systemd --user manager PERSISTS across the switch (tmux/rclone keep
  # it alive). graphical-session.target is shared by both stacks and goes
  # sticky — whichever WM starts first latches it active, so sway's later
  # `systemctl --user start sway-session.target` finds graphical-session.target
  # already up and never (re)starts waybar/kanshi → no bar after an i3→sway
  # switch. sway-session.target, by contrast, is started AND stopped per sway
  # session (see the generated `exec ... start sway-session.target && swaymsg
  # subscribe ... && stop sway-session.target`), so binding here makes the bar
  # cycle correctly every switch. Matches what the waybar.nix/kanshi.nix
  # comments already assume (the HM default flipped to graphical-session.target
  # upstream). The i3 (X11) pick is unaffected — it never binds anything to
  # sway-session.target.
  wayland.systemd.target = "sway-session.target";

  wayland.windowManager.sway = {
    enable = true;
    # On the picker host (registerSession), DON'T let home-manager install its
    # own sway: the NixOS `programs.sway` module (modules/nixos/wayland-session.nix)
    # installs a swayfx wrapped with extraSessionCommands (the Wayland env vars —
    # QT_QPA_PLATFORM=wayland etc.). HM's wayland.windowManager.sway has no
    # extraSessionCommands, so the package it would install is UNwrapped, and it
    # lands in /etc/profiles/per-user/<user>/bin which precedes
    # /run/current-system/sw/bin in the session PATH — so greetd would launch the
    # vars-less HM sway and the env vars would silently never apply (exactly the
    # bug we hit: bar fine but QT_QPA_PLATFORM empty under sway). `package = null`
    # makes HM generate only the config and defer the binary to the NixOS module.
    # (Only trade-off: no auto sway-reload on rebuild — irrelevant, we relog.)
    # When registerSession = false (the lightdm + i3 recovery generation, with
    # no NixOS programs.sway), HM keeps installing swayfx so the host isn't left
    # with no sway at all — useful for a TTY test from that generation. That
    # binary needs --unsupported-gpu baked in on DisplayLink hosts: sway
    # hard-exits at startup when the proprietary DisplayLink stack is present
    # ("displaylink" in videoDrivers loads evdi even undocked). Mirrors
    # programs.sway.extraOptions in modules/nixos/wayland-session.nix (the
    # registered-session path).
    package =
      if osConfig.modules.wayland.registerSession then
        null
      else
        pkgs.swayfx.override {
          extraOptions =
            lib.optional (lib.elem "displaylink" osConfig.services.xserver.videoDrivers)
            "--unsupported-gpu";
        };
    wrapperFeatures.gtk = true;
    # SwayFX's GLES2/DRM-backed renderer can't initialize inside the Nix build
    # sandbox, so `sway --validate` (run by the home-manager check) fails with
    # "no DRM FD available". Skip the build-time check; the config is still
    # validated at session start when sway actually runs.
    checkConfig = false;
    # SwayFX-specific eye candy directives. These aren't in the typed schema
    # so they go in extraConfig. Values mirror what picom currently does on i3.
    extraConfig = ''
      title_align center

      # Explicit cursor theme for sway's own cursor and Wayland-native
      # client cursors. Env var XCURSOR_THEME is also set (via NixOS
      # environment.sessionVariables), but the seat directive is the
      # authoritative source for sway and is what gets propagated to
      # XWayland's xcursor lookup.
      seat * xcursor_theme Bibata-Modern-Classic 24

      # SwayFX visual effects
      corner_radius 15
      smart_corner_radius enable
      shadows enable
      shadows_on_csd disable
      shadow_blur_radius 5
      shadow_color #00000080
      shadow_offset 0 0
      blur disable
      default_dim_inactive 0.15
    '';
    config = rec {
      inherit fonts;
      modifier = "Mod4";
      terminal = "kitty";
      workspaceLayout = "tabbed";
      # Window criteria: native Wayland windows expose `app_id`; XWayland
      # windows expose `class` (and never both). With NIXOS_OZONE_WL=1
      # set system-wide, Electron apps (Slack, discord, Element, Code)
      # default to native Wayland, so the i3-era `class` matches stop
      # firing. Both keys are listed so each app gets caught regardless
      # of which backend it ends up on after a packaging or env change.
      # Each `{}` is OR'd in sway criteria, so duplicates don't conflict.
      # VS Code is NOT assigned here — see the for_window rule in
      # window.commands below. It's Electron/native-Wayland and sets its
      # app_id only AFTER the window first maps, so `assign` (matched at map
      # time) misses it and it lands on the current workspace. A for_window
      # `move` rule re-fires once the app_id is known, so it lands reliably.
      assigns = {
        "\"${workspacesByKey.music}\"" = [
          { app_id = "vlc"; }
          { class = "^[Vv]lc$"; }
        ];
        "\"${workspacesByKey.avoid}\"" = [
          # Criteria are case-sensitive PCRE. sway reports these Electron
          # apps' identifiers lowercase (native Wayland app_id `slack`,
          # XWayland WM_CLASS `code`), unlike i3/X11 which capitalises the
          # WM_CLASS — so match case-insensitively. discord already happened
          # to be lowercase, which is why it alone worked before this fix.
          { app_id = "^[Ss]lack$"; }
          { class = "^[Ss]lack$"; }
          { app_id = "discord"; }
          { class = "discord"; }
          { app_id = "^[Ee]lement$"; }
          { class = "^[Ee]lement$"; }
        ];
      };
      # Disable the built-in swaybar entirely. Waybar replaces it (see
       # ./waybar.nix) and is auto-started via its systemd user service
       # bound to sway-session.target. Reason for the switch: swaybar's
       # SNI tray support only renders apps that ship embedded pixmaps,
       # which is a small minority — most apps render as the broken
       # icon placeholder.
      bars = [];
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
            command = ''move to workspace "${workspacesByKey.music}"'';
            criteria = { app_id = "^[Ss]potify$"; };
          }
          # VS Code → code workspace. Handled here (for_window) rather than via
          # `assigns` because Electron sets its identifier only after the
          # window first maps, so `assign` (matched at map time) races and
          # misses; for_window re-evaluates once it's known. In practice VS
          # Code runs under XWayland here and exposes WM_CLASS `code`
          # (lowercase — sway does not capitalise it the way i3/X11 does), so
          # the `class` rule is what actually fires. The `app_id` rule is kept
          # for a native-Wayland build. Both match case-insensitively.
          {
            command = ''move to workspace "${workspacesByKey.code}"'';
            criteria = { app_id = "^[Cc]ode$"; };
          }
          {
            command = ''move to workspace "${workspacesByKey.code}"'';
            criteria = { class = "^[Cc]ode$"; };
          }
          {
            # Picture-in-Picture from Firefox/Chrome doesn't set the
            # xdg_toplevel "dialog" hint, so sway tiles it and it fills
            # the workspace. Force float + small size + bottom-right
            # corner. Uses `ppt` (percent of output) for the position so
            # the corner is correct on both the Dell (2560x1440) and the
            # T480 standalone (1920x1080). sticky keeps it visible when
            # switching workspaces.
            command = "floating enable, sticky enable, resize set 480 270, move position 70 ppt 70 ppt";
            criteria = { title = "Picture-in-Picture"; };
          }
          # Thunar's secondary dialogs (rename, copy progress, properties,
          # confirm-overwrite, etc.) don't set the xdg_toplevel "dialog"
          # hint that sway uses to auto-float transient windows, so sway
          # tiles them and they end up filling the whole workspace. Force
          # them floating by matching their titles. app_id covers native
          # Wayland; class covers XWayland fallback. List the specific
          # dialog titles rather than "any thunar window" so the main
          # browser window keeps tiling normally.
          {
            command = "floating enable";
            criteria = {
              app_id = "thunar";
              title = "(?i)^(rename|copy|copying|move|moving|properties|confirm|file operation).*";
            };
          }
          {
            command = "floating enable";
            criteria = {
              class = "Thunar";
              title = "(?i)^(rename|copy|copying|move|moving|properties|confirm|file operation).*";
            };
          }
        ]
        # Mark these apps urgent on map so the workspace indicator
        # flashes when one opens on a non-focused workspace. Slack
        # already sets the X11 urgency hint itself; the rest don't,
        # so we force it here for parity. Both `app_id` (native
        # Wayland) and `class` (XWayland) variants are listed because
        # only one is set per window depending on the backend, and
        # several of these apps can flip between backends across
        # packaging changes.
        #
        # Wildcard `[class=".*"]`/`[app_id=".*"]` was tried first to
        # cover slow-loading apps generally, but it breaks Firefox's
        # right-click context menu (the popup never appears once the
        # main window is in urgent state). Stick to an explicit list;
        # add new entries when you find an app that needs alerting.
        ++ map
          (c: { command = "urgent enable"; criteria = c; })
          [
            { app_id = "^[Ss]lack$"; }
            { class = "^[Ss]lack$"; }
            { app_id = "discord"; }
            { class = "discord"; }
            { app_id = "^[Ee]lement$"; }
            { class = "^[Ee]lement$"; }
            { app_id = "vlc"; }
            { class = "^[Vv]lc$"; }
            { app_id = "^[Cc]ode$"; }
            { class = "^[Cc]ode$"; }
            { app_id = "^[Ss]potify$"; }
            { class = "^[Ss]potify$"; }
            { app_id = "emacs"; }
            { class = "Emacs"; }
          ];
      };
      gaps = {
        inner = 8;
        outer = 4;
        smartGaps = false;
        smartBorders = "on";
      };
      startup = [
        # The systemd --user manager persists across an i3→sway switch
        # (tmux/rclone units keep it alive), and units started by i3's
        # startup are NOT tied to any session — they linger into the sway
        # session, lose their X display, and crash-loop (redshift threw
        # "initialization of randr failed" error boxes on every i3→sway
        # switch). Stop the i3-only units explicitly; no-op when they
        # aren't running (e.g. sway-first boot). i3 does the symmetric
        # cleanup for stale Wayland env (see i3/config.nix startup).
        {
          command =
            "${pkgs.systemd}/bin/systemctl --user stop redshift.service xss-lock.service picom.service";
        }
        {
          command = "${pkgs.swaybg}/bin/swaybg -i ${wallpaper} -m fill";
          always = true;
        }
        # Waybar removed from sway exec: managed exclusively by its
        # systemd user unit now (programs.waybar.systemd.enable = true
        # in waybar.nix). Sway-exec launching couldn't enforce a
        # singleton — accidental second launches (e.g. `waybar &` from
        # a kitty during config tweaks, or `swaymsg reload` re-firing
        # exec lines on some sway versions) stayed running and stacked
        # multiple bars on the same output. systemd ownership makes a
        # second start a no-op. Mid-session reloads:
        #   pkill -SIGUSR2 waybar      # in-place reload, no restart
        #   systemctl --user restart waybar   # full restart
        # Kanshi removed from sway exec: managed exclusively by its
        # systemd user unit now (services.kanshi → kanshi.service,
        # WantedBy sway-session.target). Having both launchers caused
        # silent contention on every rebuild — see modules/home-
        # manager/kanshi.nix for the full reasoning. Edits to
        # ~/.config/kanshi/config still require:
        #   systemctl --user restart kanshi
        # or `kanshictl reload` — sway reload doesn't pick it up.
        {
          # Idle daemon — see swayidle.nix for context, swayidleCmd in the
          # let block above for the full argument list. swayidleCmd is a
          # supervised wrapper script (respawn + debug log); reference it by
          # store path.
          command = "${swayidleCmd}";
        }
        # Tray-publishing apps started via sway exec (NOT systemd
        # auto-start). Three reasons it stays this way:
        #   1. The HM-generated units carry `Requires=tray.target`,
        #      which nothing in our session graph activates — the
        #      units would block waiting on it forever.
        #   2. The WAYLAND_DISPLAY env import race at session start
        #      lands them in `failed` state before the retry budget
        #      can recover, even with bumped StartLimitBurst values.
        #   3. None of these apps suffer from the multi-instance
        #      problem that motivated moving waybar/kanshi to systemd
        #      (no SIGUSR2 reload culture, no manual restart habits),
        #      so singleton enforcement isn't a benefit here.
        # The corresponding HM units have Install.WantedBy=mkForce[]
        # to prevent the auto-start that would land them in failed
        # state — see blueman-applet.nix, udiskie.nix, host-specific.nix.
        #
        # Apps below also use the sniWait helper for the SNI host
        # registration race, plus QT_QPA_PLATFORM=xcb where the Qt6/
        # native-Wayland tray path is unreliable.
        { command = "${pkgs.blueman}/bin/blueman-applet"; }
        # kdeconnect-indicator forced through XWayland: even with sniWait
        # holding off until the watcher is up, the native-Wayland Qt6
        # build registered unreliably (showed up only after long delays
        # or never). Under XWayland it uses Qt's xcb SNI code path —
        # the same one i3 used to have working — and registers cleanly.
        # waybar still renders the resulting SNI item without issue.
        { command = sniWait "${pkgs.coreutils}/bin/env QT_QPA_PLATFORM=xcb ${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator"; }
        { command = "${pkgs.udiskie}/bin/udiskie -t"; }
        { command = "${pkgs.cbatticon}/bin/cbatticon -c '${pkgs.libnotify}/bin/notify-send \"Battery critically low!\"' -l 20 -r 10"; }
        { command = "${pkgs.cryptomator}/bin/cryptomator &"; }
        # gammastep replaces redshift on Wayland hosts (see modules/home/services.nix).
        { command = sniWait "${pkgs.gammastep}/bin/gammastep-indicator"; }
        # Qt build instead of GTK: GTK Status Icon API is X11-only and
        # silently does nothing on Wayland. Qt apps publish proper SNI
        # items, which waybar's tray module can render. Forced through
        # XWayland (QT_QPA_PLATFORM=xcb) so the toolbar/menu icons inside
        # the transmission window resolve correctly — under native Wayland
        # they render as broken/missing because Qt's icon-theme lookup
        # path differs and our config doesn't supply a Qt-native theme.
        { command = sniWait "${pkgs.coreutils}/bin/env QT_QPA_PLATFORM=xcb ${pkgs.transmission_4-qt}/bin/transmission-qt --minimized"; }
        {
          command =
            "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ 25%";
        }
        { command = "${pkgs.bitwarden-desktop}/bin/bitwarden"; }
        # numlockx is X11-only; sway uses the input config below for numlock.
        # xset DPMS/screensaver are X11-only; replaced by swayidle in Phase 2.
      ];
      input = {
        "type:keyboard" = {
          xkb_layout = "us,se";
          xkb_options = "grp:switch";
          xkb_numlock = "enabled";
        };
        # Raw libinput defaults tap to off; X11 sessions got tap-to-click
        # from the NixOS services.libinput default (tapping = true), so
        # mirror that here for parity with i3.
        "type:touchpad" = {
          tap = "enabled";
          middle_emulation = "enabled";
        };
      };
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
        # wmfocus replacement on Wayland. Pops up letter overlays on each
        # window; press the letter to focus that window.
        "g" = "exec ${pkgs.sway-easyfocus}/bin/sway-easyfocus";
        "Control+k" = "exec ${pkgs.rofi-rbw}/bin/rofi-rbw";
        "Control+p" = "exec ${pkgs.rofimoji}/bin/rofimoji --action copy";
        "t" = ''
          exec ${pkgs.libnotify}/bin/notify-send -t 5000 "`date +%H:%M`" "`date +%A` `date +%d` `date +%B` `date +%Y` - Week `date +%V`"'';
        "a" = "focus child";
        "Control+Down" = "move workspace to output down";
        "Control+Up" = "move workspace to output up";
        "Control+Left" = "move workspace to output left";
        "Control+Right" = "move workspace to output right";
        "Shift+c" = "reload";
        # 'restart' isn't a sway command; closest is exit + relogin. Reload
        # covers most config changes.
        "d" = "exec ${pkgs.rofi}/bin/rofi -show run";
        "Control+d" = "exec ${pkgs.rofi}/bin/rofi -show drun";
        "Control+w" = "exec ${pkgs.rofi}/bin/rofi -show window";
        "Control+s" = "exec ${pkgs.rofi}/bin/rofi -show ssh";
        "p" = "exec ${rofiKanshi}";
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
        "Shift+m" = "exec ${micMuteToggle}";
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

        "XF86MonBrightnessUp" = "${pkgs.brightnessctl}/bin/brightnessctl set +10%";
        "XF86MonBrightnessDown" = "${pkgs.brightnessctl}/bin/brightnessctl set 10%-";

        "XF86AudioMicMute" = micMuteToggle;

        # Wayland Print: flameshot opens an interactive picker / annotator,
        # uses xdg-desktop-portal-wlr (see modules/nixos/wayland-session.nix)
        # to grab the frame from sway. Replaces the older grim+slurp+wl-copy
        # one-liner, which only did "region → clipboard" with no UI.
        "Print" = "${pkgs.flameshot}/bin/flameshot gui";

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

  # Make the sway-config reload-on-change tolerant of a non-responsive
  # compositor. HM's stock hook (modules/services/window-managers/
  # i3-sway/sway.nix) guards on the IPC socket *file* existing, then runs
  #   swaymsg -s $sock reload
  # as the LAST command of the onChange script. During a nixos-rebuild a
  # socket file can be present while sway doesn't answer in time (mid-
  # rebuild, transient, stale pid) — swaymsg then exits 1 with "Unable to
  # receive IPC response", which propagates out of the onFilesChange
  # activation step and fails home-manager-iammrinal0.service entirely.
  # Unlike reloadSystemd, onFilesChange does not "continue anyway" on a
  # failed sub-command. The reload is a convenience (Mod+Shift+c reloads
  # manually too), so appending `|| true` makes a missed reload a no-op
  # instead of a failed system switch.
  xdg.configFile."sway/config".onChange = lib.mkForce ''
    swaySocket="''${XDG_RUNTIME_DIR:-/run/user/$UID}/sway-ipc.$UID.$(${pkgs.procps}/bin/pgrep --uid $UID -x sway | head -n1).sock"
    if [ -S "$swaySocket" ]; then
      ${pkgs.sway}/bin/swaymsg -s "$swaySocket" reload || true
    fi
  '';
}
