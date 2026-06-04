{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.flatpak;
in {
  options.modules.flatpak = {
    enable = mkEnableOption "Enable Flatpak and xdg-desktop-portal";
  };

  config = mkIf cfg.enable {
    services.flatpak.enable = true;

    # xdg-desktop-portal-gtk covers the Flatpak portal surface (file
    # pickers, opening URIs, etc.).
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      # portal ≥ 1.17 wants an explicit interface → backend mapping instead
      # of "first implementation in lexicographical order" (which is all
      # `enable` alone gives you, plus an eval warning). gtk is the only
      # backend we install, so route everything to it. (Same value as in
      # gfn.nix — equal string definitions merge cleanly if both modules
      # are enabled.)
      config.common.default = "gtk";
    };
  };
}
