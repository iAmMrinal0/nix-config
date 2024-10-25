{ ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      # package = pkgs.iosevka;
      name = "Iosevka";
    };
    themeFile = "gruvbox-dark-hard";
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
    };
  };
}
