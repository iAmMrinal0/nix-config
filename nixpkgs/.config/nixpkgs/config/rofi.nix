{
  enable = true;
  lines = 4;
  padding = 1;
  width = 30;
  borderWidth = 1;
  separator = "none";
  rowHeight = 2;
  extraConfig = "rofi.matching: fuzzy";
  scrollbar = false;
  colors = {
    window = {
      background = "#1d2021";
      border = "#a89984";
      separator = "#a89984";
    };
    rows = {
      normal = {
        background = "#1d2021";
        foreground = "#ebdbb2";
        backgroundAlt = "#282828";
        highlight = {
          background = "#504945";
          foreground = "#fbf1c7";
        };
      };
      active = {
        background = "#d79921";
        foreground = "#1d2021";
        backgroundAlt = "#d79921";
        highlight = {
          background = "#fabd2f";
          foreground = "#1d2021";
        };
      };
      urgent = {
        background = "#cc241d";
        foreground = "#1d2021";
        backgroundAlt = "#cc241d";
        highlight = {
          background = "#fb4934";
          foreground = "#1d2021";
        };
      };
    };
  };
}
