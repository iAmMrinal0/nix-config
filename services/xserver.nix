{ pkgs }:

{
  enable = true;
  exportConfiguration = true;
  displayManager = {
    lightdm = { enable = true; };
    defaultSession = "none+i3";
  };
  desktopManager = { xterm.enable = false; };
  libinput = { enable = true; };
  videoDrivers = [ "intel" ];
  windowManager.i3 = {
    enable = true;
    extraPackages =
      [ pkgs.dmenu pkgs.rofi pkgs.i3status pkgs.i3lock pkgs.i3blocks ];
    # package = pkgs.i3-gaps;
  };
}
