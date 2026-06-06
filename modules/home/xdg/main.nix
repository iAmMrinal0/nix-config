{ config, osConfig, ... }:

{
  options = { };

  config = {
    xdg = {
      enable = true;
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
