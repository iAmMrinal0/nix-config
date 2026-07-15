{ config, nixosConfig, ... }:

{
  # Settings are not managed here: email and base_url stay out of the public
  # repo, so the config is rendered by sops-nix (base.nix) and symlinked in.
  programs.rbw.enable = true;

  xdg.configFile."rbw/config.json".source =
    config.lib.file.mkOutOfStoreSymlink nixosConfig.sops.templates."rbw-config.json".path;
}
