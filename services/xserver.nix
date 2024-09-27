{ pkgs }:

{
  enable = true;
  exportConfiguration = true;
  xkb = { layout = "us"; variant = "";};
  dpi = 180;
  desktopManager = { xterm.enable = false; };
  videoDrivers = [ "intel" "displaylink" ];
  windowManager.i3 = {
    enable = true;
    extraPackages =
      [ pkgs.dmenu pkgs.rofi pkgs.i3status pkgs.i3lock pkgs.i3blocks ];
    # package = pkgs.i3-gaps;
  };
}
