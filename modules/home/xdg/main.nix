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
    };
  };
}
