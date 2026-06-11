{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.fonts;
in {
  options.modules.fonts = {
    enable = mkEnableOption "Enable font configuration";

    packages = mkOption {
      type = types.listOf types.package;
      default = [
        pkgs.cantarell-fonts
        pkgs.hasklig
        pkgs.source-code-pro
        pkgs.iosevka
        pkgs.nerd-fonts.symbols-only
        # Provides "Font Awesome 7 Free" — supplies glyphs Symbols Nerd Font
        # lacks (e.g. volume-xmark at U+F6A9, used by i3status-rust awesome6).
        pkgs.font-awesome
      ];
      description = "List of font packages to install";
    };

    enableFontconfig = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable fontconfig";
    };
  };

  config = mkIf cfg.enable {
    fonts = {
      packages = cfg.packages;
      fontconfig.enable = cfg.enableFontconfig;
    };
  };
}
