{ pkgs, ... }:

{
  services.xserver = {
    enable = true;
    exportConfiguration = true;
    # dpi = 160;
    xkb = {
      layout = "us,se";
      variant = "";
      options = "grp:switch";
    };
    desktopManager = { xterm.enable = false; };
    videoDrivers = [ "modesetting" "displaylink" ];
    windowManager.i3 = {
      enable = true;
      extraPackages = [
        pkgs.dmenu
        pkgs.rofi
        pkgs.i3status
        pkgs.i3lock
        pkgs.i3blocks
        pkgs.xkb-switch
      ];
      # package = pkgs.i3-gaps;
    };
  };
}
