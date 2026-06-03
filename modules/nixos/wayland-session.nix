{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.wayland;
in {
  options.modules.wayland = {
    enable = mkEnableOption "Install Wayland userspace tools (swayfx, kanshi, grim, etc.)";

    registerSession = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Register sway as a login session by switching the display manager from
        lightdm to greetd+tuigreet, and enable the supporting infrastructure
        (PAM service for swaylock, xdg-desktop-portal-wlr).

        Recovery: keep `modules.boot.labelSuffix = "stable-i3"` on a generation
        with this set to `false`; if greetd misbehaves, pick that generation
        from the systemd-boot menu to return to lightdm + i3.

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
      swayfx
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
    };

    # Push env vars into /etc/set-environment via environment.sessionVariables.
    # This is sourced by /etc/profile, which greetd's source_profile shell
    # invokes before exec'ing the session command — so every login session
    # picks them up. We tried programs.sway.extraSessionCommands and a
    # launcher script first; both had subtle propagation issues in this
    # config (the wrapped binary's extraSessionCommands kept evaluating to
    # empty, and the launcher's exports didn't survive greetd's chain).
    # environment.sessionVariables is the canonical NixOS path and works
    # reliably because it's set BEFORE the session command runs.
    environment.sessionVariables = mkIf cfg.registerSession {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      GDK_BACKEND = "wayland,x11";
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";
      # Kirigami / KF6 apps (kdeconnect-app etc.) need QtQuick Controls
      # pointed at the desktop style — without it they fall back to
      # default Fusion light (white bg, grey buttons, black text).
      # Pairs with kdePackages.qqc2-desktop-style in home/packages.nix
      # (the QML plugin that provides this style) and the BreezeDark
      # kdeglobals in modules/home-manager/qt.nix (the color scheme it
      # reads colors from).
      QT_QUICK_CONTROLS_STYLE = "org.kde.desktop";
      # QT_QPA_PLATFORMTHEME and QT_STYLE_OVERRIDE moved to the NixOS
      # `qt` module below — that module owns the env vars, installs
      # qt5ct/qt6ct + Adwaita style plugins, and writes the values to
      # /etc/pam/environment the same way explicit sessionVariables
      # do. The previous setup (QT_QPA_PLATFORMTHEME=adwaita) was a
      # silent no-op: adwaita-qt only ships plugins/styles/adwaita.so,
      # not plugins/platformthemes/adwaita.so, so Qt couldn't load
      # the platform theme and never read gtk-icon-theme-name from
      # gtk.nix — leaving transmission's torrent-row mime icons stuck
      # on the hicolor "generic file" fallback. qtct is a real
      # platform-theme plugin and reads its own config from
      # ~/.config/qt5ct/qt5ct.conf (deployed by HM qt.nix).
      # Bitwarden's SSH agent socket. Duplicates home.sessionVariables
      # (which still apply for mordor's lightdm + login-shell session)
      # because greetd → tuigreet → sway exec's sway directly without a
      # login shell, so home-manager session vars don't reach sway-launched
      # GUI apps. Bitwarden therefore starts without BITWARDEN_SSH_AUTH_SOCK
      # and its SSH agent never binds the configured socket — keys never
      # get added on unlock. Routing these through PAM via
      # environment.sessionVariables (→ /etc/pam/environment, which PAM
      # loads before greetd execs the session) gets them into sway's env
      # the same way NIXOS_OZONE_WL etc. arrive. PAM translates $HOME to
      # @{HOME} for per-session expansion.
      SSH_AUTH_SOCK = "$HOME/.local/share/ssh-agent";
      BITWARDEN_SSH_AUTH_SOCK = "$HOME/.local/share/ssh-agent";
    };

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

    services.greetd = mkIf cfg.registerSession {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          # `--cmd sway` resolves via PATH after greetd's source_profile
          # shell sources /etc/profile, which sources /etc/set-environment
          # (populated by environment.sessionVariables above). By the time
          # sway exec's, all our env vars are present.
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
              --time \
              --remember \
              --asterisks \
              --cmd sway
          '';
          # `--remember-user-session` removed deliberately. It causes
          # tuigreet to cache the resolved store-path of the launched
          # session in /var/cache/tuigreet/lastsession-<user> and re-
          # exec that exact path on the next login. After a `nix-
          # collect-garbage` reaps the old generation the cached path
          # is dead, PAM's session shell errors with
          #   sh: <nix-store-path>: No such file or directory
          # and the login screen loops endlessly with no actionable
          # message. `--cmd sway` alone resolves through PATH at every
          # exec, so it always picks up the current generation's sway.
          # `--remember` (username only) is fine to keep.
          user = "greeter";
        };
      };
    };
  };
}
