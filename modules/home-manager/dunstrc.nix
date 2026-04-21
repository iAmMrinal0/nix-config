{ config, pkgs, ... }:

let colors = config.personal.theming.colors;
in {
  services.dunst = {
    enable = true;
    iconTheme.package = pkgs.papirus-icon-theme;
    iconTheme.name = "Papirus-Dark";
    iconTheme.size = "48";
    settings = {
      global = {
        font = "Iosevka Nerd Font 12";
        markup = "yes";
        # plain_text = "no";
        format = "<b>%s</b>\\n%b";
        transparency = "10";
        corner_radius = 10;
        ignore_newline = "no";
        show_indicators = "yes";
        separator_color = "frame";
        sort = "yes";
        alignment = "center";
        word_wrap = "yes";
        indicate_hidden = "yes";
        show_age_threshold = "60";
        idle_threshold = "120";
        # geometry = "500x5-10+30";
        width = 500;
        height = 300;
        offset = "10x30";
        shrink = "no";
        line_height = "0";
        # notification_height = "100";
        separator_height = "2";
        padding = "8";
        horizontal_padding = "8";
        monitor = "0";
        follow = "mouse";
        sticky_history = "false";
        history_length = "20";
        icon_position = "left";
        max_icon_size = 65;
        # startup_notification = "true";
        frame_width = "2";
        frame_color = colors.accent;
      };

      urgency_low = {
        background = colors.bg1;
        foreground = colors.fgMuted;
        frame_color = colors.blue;
        timeout = 10;
      };

      urgency_normal = {
        background = colors.bg1;
        foreground = colors.fg;
        frame_color = colors.aqua;
        timeout = 5;
      };

      urgency_critical = {
        background = colors.bg1;
        foreground = colors.fg;
        frame_color = colors.red;
        timeout = 0;
      };
    };
  };
}
