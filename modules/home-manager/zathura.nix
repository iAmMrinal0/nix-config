{ config, ... }:

let colors = config.personal.theming.colors;
in {
  programs.zathura = {
    enable = true;
    extraConfig = ''
      set font                        "Source Code Pro 10"
      set default-bg                  "${colors.bg1}"
      set default-fg                  "${colors.fg}"

      set statusbar-fg                "${colors.fg}"
      set statusbar-bg                "${colors.bg1}"

      set inputbar-bg                 "${colors.bg1}"
      set inputbar-fg                 "${colors.fg}"

      set notification-error-bg       "${colors.bg1}"
      set notification-error-fg       "${colors.red}"

      set notification-warning-bg     "${colors.bg1}"
      set notification-warning-fg     "${colors.yellow}"

      set highlight-color             "${colors.bg1}"
      set highlight-active-color      "${colors.fg}"

      set completion-highlight-fg     "${colors.bg2}"
      set completion-highlight-bg     "${colors.aqua}"

      set completion-bg               "${colors.bg2}"
      set completion-fg               "${colors.fg}"

      set notification-bg             "${colors.bg1}"
      set notification-fg             "${colors.blue}"

      set recolor-lightcolor          "${colors.bg1}"
      set recolor-darkcolor           "${colors.fg}"
      set recolor                     "false"

      # setting recolor-keep true will keep any color your pdf has.
      # if it is false, it'll just be black and white
      set recolor-keephue "false"

      set selection-clipboard "clipboard"

      # keybindings
      map [fullscreen] a adjust_window best-fit
      map [fullscreen] s adjust_window width
      map [fullscreen] f follow
      map [fullscreen] <Tab> toggle_index
      map [fullscreen] j scroll down
      map [fullscreen] k scroll up
      map [fullscreen] h navigate previous
      map [fullscreen] l navigate next
    '';
  };
}
