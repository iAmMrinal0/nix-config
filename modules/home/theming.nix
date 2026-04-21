{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.personal.theming;
  colors = cfg.colors;
in {
  options.personal.theming = {
    enable = mkEnableOption "personal theme settings";

    colors = {
      # Base surfaces (darkest to lightest). Gruvbox Material medium-dark.
      bg0 = mkOption {
        type = types.str;
        default = "#282828";
        description = "Primary background (darkest).";
      };
      bg1 = mkOption {
        type = types.str;
        default = "#32302f";
        description = "Secondary background surface.";
      };
      bg2 = mkOption {
        type = types.str;
        default = "#45403d";
        description = "Tertiary background / subtle border.";
      };

      # Foreground variants
      fg = mkOption {
        type = types.str;
        default = "#d4be98";
        description = "Primary foreground text color.";
      };
      fgBright = mkOption {
        type = types.str;
        default = "#ebdbb2";
        description = "Brighter foreground for focused / emphasized text.";
      };
      fgMuted = mkOption {
        type = types.str;
        default = "#a89984";
        description = "Muted foreground (inactive / secondary text).";
      };
      comment = mkOption {
        type = types.str;
        default = "#928374";
        description = "Comment / low-emphasis foreground.";
      };

      # Semantic palette — pastel Material accents.
      red = mkOption {
        type = types.str;
        default = "#ea6962";
        description = "Red / error / urgent.";
      };
      orange = mkOption {
        type = types.str;
        default = "#e78a4e";
        description = "Orange / accent / warn.";
      };
      yellow = mkOption {
        type = types.str;
        default = "#d8a657";
        description = "Yellow.";
      };
      green = mkOption {
        type = types.str;
        default = "#a9b665";
        description = "Green / success.";
      };
      aqua = mkOption {
        type = types.str;
        default = "#89b482";
        description = "Aqua / teal.";
      };
      blue = mkOption {
        type = types.str;
        default = "#7daea3";
        description = "Blue / info.";
      };
      purple = mkOption {
        type = types.str;
        default = "#d3869b";
        description = "Purple / pink accent.";
      };

      # Derived / semantic aliases
      urgent = mkOption {
        type = types.str;
        default = colors.red;
        description = "Urgent / critical highlight.";
      };
      border = mkOption {
        type = types.str;
        default = colors.bg2;
        description = "Default window / UI border.";
      };
      borderFocused = mkOption {
        type = types.str;
        default = colors.fgMuted;
        description = "Focused window / UI border.";
      };

      # Backwards-compat aliases (kept so existing callers keep working)
      primary = mkOption {
        type = types.str;
        default = colors.fg;
        description = "Primary color for UI elements (alias of fg).";
      };
      background = mkOption {
        type = types.str;
        default = colors.bg0;
        description = "Background color (alias of bg0).";
      };
      accent = mkOption {
        type = types.str;
        default = colors.orange;
        description = "Accent color (alias of orange).";
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
      color-normal = "${colors.bg0},${colors.fg}";
      color-active = "${colors.bg0},${colors.accent}";
    };

  };
}
