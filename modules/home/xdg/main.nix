{ config, osConfig, ... }:

{
  options = { };

  config = {
    xdg = {
      enable = true;
      # Declarative user dirs: user-dirs.dirs becomes HM-managed instead of
      # mutable state written by xdg-user-dirs-update, and the dirs are
      # created on activation — a fresh $HOME comes up deterministic.
      # Templates/Public are nulled (never used); they won't be created on
      # new machines, existing empty ones can be rmdir'd.
      userDirs = {
        enable = true;
        createDirectories = true;
        # Adopt the 26.05 default (stateVersion 24.05 would otherwise warn
        # and keep the legacy `true`): don't export XDG_DOWNLOAD_DIR & co.
        # as session variables — nothing in this config reads them (verified
        # by grep), apps get the dirs from user-dirs.dirs directly.
        setSessionVariables = false;
        desktop = "${config.home.homeDirectory}/Desktop";
        documents = "${config.home.homeDirectory}/Documents";
        download = "${config.home.homeDirectory}/Downloads";
        music = "${config.home.homeDirectory}/Music";
        pictures = "${config.home.homeDirectory}/Pictures";
        videos = "${config.home.homeDirectory}/Videos";
        templates = null;
        publicShare = null;
      };
      # pgcli configs are rendered at system activation by sops-nix
      # (modules/nixos/pgcli.nix): benign base from config/pgcli plus the
      # secret [alias_dsn] sections appended, per-environment variants
      # included. Symlinked out of store so the DSNs never enter /nix/store.
      configFile."pgcli/config".source = config.lib.file.mkOutOfStoreSymlink
        osConfig.sops.templates."pgcli-config".path;
      configFile."pgcli/pgcli-prod".source = config.lib.file.mkOutOfStoreSymlink
        osConfig.sops.templates."pgcli-prod".path;
      configFile."pgcli/pgcli-staging".source =
        config.lib.file.mkOutOfStoreSymlink
        osConfig.sops.templates."pgcli-staging".path;

      # Default application associations (mimeapps.list). Apps occasionally
      # rewrite this file at runtime ("Set as default" / xdg-mime), which
      # would turn the HM symlink back into a regular file and abort the next
      # activation on the backup conflict — so force-overwrite, same as
      # gtk-3.0/bookmarks. The magnet handler points at the canonical
      # transmission-gtk.desktop rather than the runtime-generated
      # userapp-transmission-gtk-*.desktop alias that was in the mutable file.
      configFile."mimeapps.list".force = true;
      mimeApps = {
        enable = true;
        defaultApplications = {
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
          "x-scheme-handler/chrome" = "firefox.desktop";
          "text/html" = "firefox.desktop";
          "application/xhtml+xml" = "firefox.desktop";
          "application/x-extension-htm" = "firefox.desktop";
          "application/x-extension-html" = "firefox.desktop";
          "application/x-extension-shtml" = "firefox.desktop";
          "application/x-extension-xhtml" = "firefox.desktop";
          "application/x-extension-xht" = "firefox.desktop";
          "x-scheme-handler/magnet" = "transmission-gtk.desktop";
          "image/png" = "feh.desktop";
          "image/jpeg" = "feh.desktop";
          "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
          "application/zip" = "xarchiver.desktop";
          "text/plain" = "code.desktop";
          "application/x-zerosize" = "code.desktop";
        };
      };
    };
  };
}
