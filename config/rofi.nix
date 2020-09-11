{ pkgs, ...}:
{
  enable = true;
  lines = 5;
  padding = 1;
  width = 30;
  borderWidth = 1;
  separator = "none";
  rowHeight = 2;
  extraConfig = "rofi.matching: fuzzy";
  scrollbar = false;
  terminal = "${pkgs.kitty}/bin/kitty";
  theme = "gruvbox-dark-hard";
}
