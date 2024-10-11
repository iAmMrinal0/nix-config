{ pkgs }:

{
  enable = true;
  exportConfiguration = true;
  dpi = 180;
  xkb = { layout = "us,se"; variant = ""; options = "grp:alt_shift_toggle";};
  desktopManager = { xterm.enable = false; };
  videoDrivers = [ "intel" "displaylink" ];
  windowManager.i3 = {
    enable = true;
    extraPackages =
      [ pkgs.dmenu pkgs.rofi pkgs.i3status pkgs.i3lock pkgs.i3blocks pkgs.xkb-switch ];
    # package = pkgs.i3-gaps;
  };
}
