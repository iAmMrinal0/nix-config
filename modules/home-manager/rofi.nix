{ pkgs, ... }: {
  programs.rofi = {
    enable = true;

    # lines = 5;
    # padding = 1;
    # width = 30;
    # borderWidth = 1;
    # separator = "none";
    # rowHeight = 2;
    # extraConfig = { };
    # scrollbar = false;
    # terminal = "${pkgs.kitty}/bin/kitty";
    # font = "Iosevka 25";
    plugins = [ pkgs.rofi-calc ];
    # Theme is now managed by the theming module
    # theme = "gruvbox-dark-hard";
    extraConfig = {
      # hide-scrollbar = true;
      # separator = "none";
      matching = "fuzzy";
      # padding = 1;
      # rowHeight = 2;
      # borderWidth = 1;
      # lines = 5;
      # width = 30;
    };
  };
}
