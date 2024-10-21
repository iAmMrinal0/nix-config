{ pkgs, ... }:

{
  enable = true;
  font = {
    # package = pkgs.iosevka;
    name = "Iosevka";
  };
  settings = {
    font_size = "16.0";
    cursor_shape = "beam";
    scrollback_lines = 100000;
    # background_opacity = "0.3";
    enable_audio_bell = false;
    copy_on_select = "yes";
    focus_follows_mouse = "yes";
    hide_window_decorations = "yes";
    update_check_interval = 0;
    visual_bell_duration = 0;
    window_alert_on_bell = "no";
    foreground = "#ebdbb2";
    background = "#1d2021";
    selection_foreground = "#655b53";
    selection_background = "#ebdbb2";
    url_color = "#d65c0d";
    macos_option_as_alt = "yes";
    # black
    color0 = "#272727";
    color8 = "#928373";

    # red
    color1 = "#cc231c";
    color9 = "#fb4833";

    # green
    color2 = "#989719";
    color10 = "#b8ba25";

    # yellow
    color3 = "#d79920";
    color11 = "#fabc2e";

    # blue
    color4 = "#448488";
    color12 = "#83a597";

    # magenta
    color5 = "#b16185";
    color13 = "#d3859a";

    # cyan
    color6 = "#689d69";
    color14 = "#8ec07b";

    # white
    color7 = "#a89983";
    color15 = "#ebdbb2";
  };
}
