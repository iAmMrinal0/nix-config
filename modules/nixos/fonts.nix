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
