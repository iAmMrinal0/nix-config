{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.personal.theming;
in
{
  options.personal.theming = {
    enable = mkEnableOption "personal theme settings";
    
    colors = {
      primary = mkOption {
        type = types.str;
        default = "#ebdbb2";  # Gruvbox foreground
        description = "Primary color for UI elements";
        example = "#ffffff";
      };
      
      background = mkOption {
        type = types.str;
        default = "#1d2021";  # Gruvbox background
        description = "Background color for UI elements";
        example = "#000000";
      };
      
      accent = mkOption {
        type = types.str;
        default = "#fe8019";  # Gruvbox orange
        description = "Accent color for highlights and selections";
        example = "#ff0000";
      };
    };
    
    font = {
      regular = mkOption {
        type = types.str;
        default = "Source Code Pro";
        description = "Default regular font name";
      };
      
      size = mkOption {
        type = types.int;
        default = 12;
        description = "Default font size";
      };
      
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Font package to install";
        example = "pkgs.iosevka";
      };
    };
    
    rofi = {
      theme = mkOption {
        type = types.str;
        default = "gruvbox-dark-hard";
        description = "The rofi theme to use";
        example = "android_notification";
      };
    };
    
    kitty = {
      theme = mkOption {
        type = types.str;
        default = "gruvbox-dark-hard";
        description = "Kitty theme to use";
        example = "Dracula";
      };
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = mkIf (cfg.font.package != null) [ cfg.font.package ];
    
    programs.kitty = {
      settings = {
        font_family = cfg.font.regular;
        # Convert to string to ensure compatibility with kitty's expectations
        font_size = toString cfg.font.size;
      };
      
      font = mkIf (cfg.font.package != null) {
        package = cfg.font.package;
        name = cfg.font.regular;
      };
      
      themeFile = cfg.kitty.theme;
    };
    
    programs.rofi.theme = mkIf config.programs.rofi.enable cfg.rofi.theme;
    programs.rofi.extraConfig = mkIf config.programs.rofi.enable {
      color-normal = "${cfg.colors.background},${cfg.colors.primary}";
      color-active = "${cfg.colors.background},${cfg.colors.accent}";
    };
    
  };
}
