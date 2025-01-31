{ ... }: {
  programs.zathura = {
    enable = true;
    extraConfig = ''
      set font                        "Source Code Pro 10"
      set default-bg                  "#262626" #00
      set default-fg                  "#ebdbb2" #01

      set statusbar-fg                "#ebdbb2" #04
      set statusbar-bg                "#262626" #01

      set inputbar-bg                 "#262626" #00 currently not used
      set inputbar-fg                 "#ebdbb2" #02

      set notification-error-bg       "#262626" #08
      set notification-error-fg       "#cc241d" #00

      set notification-warning-bg     "#262626" #08
      set notification-warning-fg     "#d79921" #00

      set highlight-color             "#262626" #0A
      set highlight-active-color      "#ebdbb2" #0D

      set completion-highlight-fg     "#4e4e4e" #02
      set completion-highlight-bg     "#87afaf" #0C

      set completion-bg               "#4e4e4e" #02
      set completion-fg               "#ebdbb2" #0C

      set notification-bg             "#262626" #0B
      set notification-fg             "#458588" #00

      set recolor-lightcolor          "#262626" #00
      set recolor-darkcolor           "#ebdbb2" #06
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
