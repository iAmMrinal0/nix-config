{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.wayland;
  # NixOS aggregates every WM/DM .desktop file (sway.desktop from
  # programs.sway, none+i3.desktop from services.xserver.windowManager.i3)
  # into this derivation under share/{wayland-sessions,xsessions}. This is
  # where session files actually live — NOT /run/current-system/sw/share,
  # which only carries .desktop files shipped inside packages (so sway's
  # would appear there but the generated none+i3.desktop would not).
  sessionData = config.services.displayManager.sessionData;
  # Shared X11 session wrapper, the same one lightdm runs: it sources
  # /etc/profile + ~/.xprofile, runs services.xserver.displayManager
  # .sessionCommands (our dbus-update-activation-environment DISPLAY) and
  # merges xrdb before exec'ing the session. The generated none+i3.desktop
  # Exec is a bare `exec i3` that assumes X is already up and does NOT go
  # through this wrapper on its own, so we prepend `startx` (brings up an X
  # server via /etc/X11/xinit/xserverrc) and hand the wrapper to it. Result
  # for an X11 pick: startx → X server → xsession-wrapper → i3, matching the
  # old lightdm path. Wayland sessions (sway) ignore this wrapper entirely.
  xsessionWrapper = "startx ${sessionData.wrapper}";
  # Filtered copy of sessionData.desktops for the tuigreet menu. The
  # displayManager module lndirs the ENTIRE share/wayland-sessions dir of
  # every session package (passthru.providedSessions only feeds
  # sessionNames, it does not filter the files), and pkgs.hyprland ships
  # hyprland-uwsm.desktop alongside hyprland.desktop. With
  # programs.hyprland.withUWSM off, uwsm isn't installed, so that entry
  # would be a landmine in the menu: picking it fails at exec and dumps
  # you back at the greeter. Drop it here — this derivation is only ever
  # referenced by the tuigreet flags below, everything else keeps reading
  # sessionData.desktops.
  menuSessions = pkgs.runCommand "tuigreet-menu-sessions" { } ''
    mkdir -p $out/share
    ${pkgs.buildPackages.lndir}/bin/lndir -silent ${sessionData.desktops}/share $out/share
    rm -f $out/share/wayland-sessions/hyprland-uwsm.desktop
  '';
in {
  options.modules.wayland = {
    enable = mkEnableOption "Install Wayland userspace tools (swayfx, kanshi, grim, etc.)";

    registerSession = mkOption {
      type = types.bool;
      default = false;
      description = ''
        `true`  → greetd + tuigreet session PICKER: the login screen lists
                  both i3 (X11) and sway (Wayland) and you choose per login,
                  no rebuild to switch. Also enables the supporting
                  infrastructure (startx for the X11 pick, PAM service for
                  swaylock, xdg-desktop-portal-wlr).
        `false` → known-good lightdm + i3 only (no greetd in the path). This
                  is the recovery/escape-hatch generation.

        Recovery: keep `modules.boot.labelSuffix = "stable-i3"` on a generation
        with this set to `false`; if greetd or the picker misbehaves, pick that
        generation from the systemd-boot menu to return to lightdm + i3.

        Operational note: switch the display manager via `nixos-rebuild boot`
        and reboot, not `switch`. Switching live would tear down lightdm and
        try to start greetd in the same boot, which is brittle.
      '';
    };

    windowManager = {
      sway = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Sway (SwayFX) window manager support";
        };
      };
      hyprland = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Enable Hyprland as an additional session-picker entry (third
            alongside i3 and sway). Only takes effect together with
            registerSession — without the picker there is no way to launch
            it, so nothing is installed.
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Always install the Wayland tools so the home-manager sway config can
    # reference them and so the user can `swaymsg`, `grim`, etc. from a TTY
    # or X11 session for testing. Installing the binaries does not touch
    # the display manager.
    #
    # Icon themes are added at the system level (not just the user's GTK
    # profile) so that swaybar's StatusNotifierItem tray can resolve icon
    # names against /run/current-system/sw/share/icons. Without these,
    # tray entries that publish only an icon name (no embedded pixmap)
    # render as the "icon not found" red sad face.
    environment.systemPackages = mkIf cfg.windowManager.sway.enable (with pkgs; [
      # NB: do NOT list swayfx here. `programs.sway` (below) already installs
      # the wrapped swayfx into PATH, and that wrapper is the one carrying
      # extraSessionCommands (the Wayland env vars). Listing plain `swayfx`
      # here too put a SECOND, unwrapped `bin/sway` in the buildEnv that won
      # the collision — so the session ran with an empty session-command
      # wrapper and none of the QT_QPA_PLATFORM/NIXOS_OZONE_WL/etc. vars set.
      swaybg
      swaylock
      swayidle
      grim
      slurp
      wl-clipboard
      kanshi
      wdisplays
      brightnessctl
      playerctl
      papirus-icon-theme
      adwaita-icon-theme
      hicolor-icon-theme
      # Cursor theme installed system-wide so sway compositor finds it via
      # /run/current-system/sw/share/icons (XCURSOR_PATH default lookup
      # path), independent of user-profile state.
      bibata-cursors
      # qgnomeplatform was here previously to back QT_QPA_PLATFORMTHEME=gtk3,
      # but it crashed transmission-qt in its Application constructor (segv
      # in Qt platform plugin init). Removed; QT_QPA_PLATFORMTHEME=gtk3 in
      # sessionVariables is also removed so Qt apps fall back to their
      # Adwaita-Qt style (configured in modules/home-manager/qt.nix).
    ]);

    # Everything below modifies the display manager and session graph. Gated
    # behind registerSession so it only takes effect on intentional cutover.
    programs.sway = mkIf (cfg.windowManager.sway.enable && cfg.registerSession) {
      enable = true;
      package = pkgs.swayfx;
      wrapperFeatures.gtk = true;
      # sway hard-exits at startup when the proprietary DisplayLink stack is
      # in use (sway/server.c check; hit on mordor's first office TTY test).
      # --unsupported-gpu is the documented escape hatch. Conditioned on the
      # displaylink video driver (currently the xserver.nix default on BOTH
      # hosts, so in practice this lands everywhere; betazed's guard never
      # fired since no DisplayLink hardware ever appears there — the flag is
      # inert without it). The module plumbs this into the wrapped package
      # via package.override.
      extraOptions =
        lib.optional (lib.elem "displaylink" config.services.xserver.videoDrivers)
        "--unsupported-gpu";
      # Wayland-only env vars, scoped to the SWAY session (not system-wide).
      # The base wrapper (wrapperFeatures.base, default true) runs these just
      # before exec'ing sway, so they land in sway's process env and are
      # inherited by everything sway exec's — rofi, kitty, and the GUI apps
      # launched from them. They are deliberately kept OUT of
      # environment.sessionVariables: that path is system-wide
      # (/etc/pam/environment + /etc/set-environment) and would also apply
      # under the i3 (X11) session picked from the SAME generation, where
      # QT_QPA_PLATFORM=wayland makes Qt apps abort (no compositor to talk
      # to). Splitting them here is what lets one generation serve both
      # stacks. (waybar/kanshi run as systemd --user units and don't need
      # these; the tray apps override QT_QPA_PLATFORM=xcb at their own exec.)
      extraSessionCommands = ''
        export NIXOS_OZONE_WL=1
        export MOZ_ENABLE_WAYLAND=1
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        export SDL_VIDEODRIVER=wayland
        export _JAVA_AWT_WM_NONREPARENTING=1
        # GDK_BACKEND moved here too (was system-wide): "wayland,x11" under i3
        # would just probe a non-existent Wayland display before falling back
        # to X11 — harmless but pointless off-Wayland, so scope it to sway.
        export GDK_BACKEND=wayland,x11
        # Kirigami / KF6 apps (kdeconnect-app etc.) need QtQuick Controls
        # pointed at the desktop style — without it they fall back to
        # default Fusion light (white bg, grey buttons, black text).
        # Pairs with kdePackages.qqc2-desktop-style in home/packages.nix
        # (the QML plugin that provides this style) and the BreezeDark
        # kdeglobals in modules/home-manager/qt.nix (the color scheme it
        # reads colors from).
        export QT_QUICK_CONTROLS_STYLE=org.kde.desktop
      '';
    };

    # Hyprland as the third picker entry. The NixOS module does everything
    # the picker needs in one shot: installs the package system-wide (plus a
    # cap_sys_nice security wrapper in /run/wrappers/bin that the session
    # Exec resolves first in PATH), registers hyprland.desktop via
    # services.displayManager.sessionPackages (→ sessionData → tuigreet's
    # --sessions menu, same path sway.desktop takes), and wires
    # xdg-desktop-portal-hyprland with the package's own portals.conf
    # (routed per XDG_CURRENT_DESKTOP=Hyprland, so it coexists with the
    # sway/wlr portal block below).
    #
    # One-binary rule (the swayfx shadowing bug, see systemPackages note
    # above): this module is the ONLY place that installs hyprland — do not
    # list it in environment.systemPackages, and the home-manager side sets
    # wayland.windowManager.hyprland.package = null (config generation only).
    #
    # Env vars: programs.hyprland has NO extraSessionCommands equivalent —
    # the Wayland-only var set lives as `env =` lines in the HM config
    # (modules/home-manager/hyprland/config.nix), which load before
    # exec-once / any client and are inherited by everything Hyprland
    # execs. Keep that list in sync with programs.sway.extraSessionCommands
    # above.
    programs.hyprland =
      mkIf (cfg.windowManager.hyprland.enable && cfg.registerSession) {
        enable = true;
        # withUWSM deliberately off: UWSM would own graphical-session.target
        # wiring; our per-WM-target scheme (hyprland-session.target via the
        # HM module) is what keeps waybar/kanshi cycling correctly across
        # WM switches — see gotcha #2 in MULTI_SESSION_HANDOFF.md.
      };

    # System-wide session vars that are safe (or needed) on BOTH stacks, so
    # they stay in environment.sessionVariables → /etc/set-environment (sourced
    # by /etc/profile, which greetd's source_profile shell runs before exec'ing
    # the chosen session) and /etc/pam/environment (loaded by PAM at session
    # open). The Wayland-only vars that used to live here moved to
    # programs.sway.extraSessionCommands above — keeping QT_QPA_PLATFORM=wayland
    # etc. system-wide would break Qt/Electron under the i3 (X11) pick.
    environment.sessionVariables = mkIf cfg.registerSession {
      # Cursor theme: harmless on X11, so it stays system-wide (and the
      # sway compositor also resolves it via XCURSOR_PATH — see the
      # bibata-cursors note in systemPackages above).
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";
      # Bitwarden's SSH agent socket. Duplicates home.sessionVariables
      # (which still apply for mordor's lightdm + login-shell session)
      # because greetd → tuigreet → session exec's the WM directly without a
      # login shell, so home-manager session vars don't reach WM-launched
      # GUI apps. Bitwarden therefore starts without BITWARDEN_SSH_AUTH_SOCK
      # and its SSH agent never binds the configured socket — keys never
      # get added on unlock. Routing these through PAM via
      # environment.sessionVariables (→ /etc/pam/environment, which PAM
      # loads before greetd execs the session) gets them into the session
      # env on both stacks. PAM translates $HOME to @{HOME} for per-session
      # expansion. These must stay system-wide (not in the sway wrapper)
      # because they're needed under i3 too.
      SSH_AUTH_SOCK = "$HOME/.local/share/ssh-agent";
      BITWARDEN_SSH_AUTH_SOCK = "$HOME/.local/share/ssh-agent";
    };

    # QT_QPA_PLATFORMTHEME and QT_STYLE_OVERRIDE are owned by the NixOS `qt`
    # module below (not environment.sessionVariables) — that module installs
    # qt5ct/qt6ct + Adwaita style plugins and writes the values to
    # /etc/pam/environment itself. They stay system-wide on purpose: qt5ct
    # works on X11 too, so they're correct under both i3 and sway. The
    # previous setup (QT_QPA_PLATFORMTHEME=adwaita) was a silent no-op:
    # adwaita-qt only ships plugins/styles/adwaita.so, not
    # plugins/platformthemes/adwaita.so, so Qt couldn't load the platform
    # theme and never read gtk-icon-theme-name from gtk.nix — leaving
    # transmission's torrent-row mime icons stuck on the hicolor "generic
    # file" fallback. qtct is a real platform-theme plugin and reads its own
    # config from ~/.config/qt5ct/qt5ct.conf (deployed by HM qt.nix).
    #
    # NixOS qt module: installs qt5ct + qt6ct (the qtct platform theme
    # plugin) and the Adwaita style plugins for Qt5 + Qt6, and exports
    # QT_QPA_PLATFORMTHEME=qt5ct + QT_STYLE_OVERRIDE=Adwaita-Dark via
    # /etc/pam/environment. With the platform-theme plugin actually on
    # disk under plugins/platformthemes/, Qt loads it at startup, the
    # plugin reads ~/.config/qt5ct/qt5ct.conf (icon_theme=Papirus,
    # style=Adwaita-Dark — see modules/home-manager/qt.nix), and Qt's
    # QIcon resolution finally honors Papirus for mime icons.
    qt = mkIf cfg.registerSession {
      enable = true;
      platformTheme = "qt5ct";
      style = "adwaita-dark";
    };

    # XDG desktop portal for screen sharing, file pickers, etc. on Wayland.
    # NixOS's programs/wayland/sway.nix already sets a `default = gtk`
    # routing for XDG_CURRENT_DESKTOP=sway, so we only pin the two
    # interfaces that need the wlr backend (Screencast + Screenshot — wlr
    # is the one that actually knows how to talk to sway for frames).
    # FileChooser + everything else stays on gtk via the module default;
    # we don't override `default` because doing so collides with the
    # sway module's definition.
    xdg.portal = mkIf (cfg.windowManager.sway.enable && cfg.registerSession) {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.sway = {
        "org.freedesktop.impl.portal.Screencast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };

    security.pam.services.swaylock.enable =
      mkIf (cfg.windowManager.sway.enable && cfg.registerSession) true;

    # Switch from lightdm (auto-enabled by services.xserver.enable = true) to
    # greetd+tuigreet. greetd runs as a TTY service and hands off cleanly to
    # Wayland sessions without lightdm's X-tear-down dance.
    services.xserver.displayManager.lightdm.enable =
      mkIf cfg.registerSession (mkForce false);

    # Enable the "startx" pseudo-display-manager. It registers NO
    # display-manager.service (greetd owns that), so it coexists with greetd;
    # all it contributes is the `startx`/`xinit` binary in PATH and a correct
    # /etc/X11/xinit/xserverrc that launches NixOS's X with the configured
    # xserverArgs. tuigreet's --xsession-wrapper relies on this `startx` to
    # bring up an X server when the i3 (X11) session is picked.
    services.xserver.displayManager.startx.enable = mkIf cfg.registerSession true;

    services.greetd = mkIf cfg.registerSession {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          # Session-menu mode (replaces the old `--cmd sway`): tuigreet reads
          # the session .desktop files and lets you pick i3 (X11) or sway
          # (Wayland) per login, no rebuild to switch. greetd's source_profile
          # shell sources /etc/profile (→ /etc/set-environment from
          # environment.sessionVariables) before running the chosen session,
          # so env vars are present at exec time for both stacks.
          #
          # tuigreet 0.9.1 flag forms (verified against the pinned source):
          #   --sessions DIRS   colon-separated Wayland session dirs
          #   --xsessions DIRS  colon-separated X11 session dirs
          #   --xsession-wrapper 'CMD'  command X11 sessions are wrapped with
          #     (default is `startx /usr/bin/env`, which would skip our X
          #     session setup — we override it, see xsessionWrapper above).
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
              --time \
              --remember \
              --asterisks \
              --sessions ${menuSessions}/share/wayland-sessions \
              --xsessions ${menuSessions}/share/xsessions \
              --xsession-wrapper "${xsessionWrapper}"
          '';
          # `--remember-user-session` removed deliberately. It causes
          # tuigreet to cache the resolved store-path of the launched
          # session in /var/cache/tuigreet/lastsession-<user> and re-
          # exec that exact path on the next login. After a `nix-
          # collect-garbage` reaps the old generation the cached path
          # is dead, PAM's session shell errors with
          #   sh: <nix-store-path>: No such file or directory
          # and the login screen loops endlessly with no actionable
          # message. Session-menu mode resolves the chosen .desktop fresh
          # from sessionData on every login, so it always points at the
          # current generation. `--remember` (username only) is fine to keep.
          user = "greeter";
        };
      };
    };
  };
}
