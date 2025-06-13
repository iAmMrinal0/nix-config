{ pkgs }:

{
  rofi-autorandr = pkgs.callPackage ./rofi-autorandr { };
  
  shutdown-menu = pkgs.callPackage ./shutdown-menu { };
  current-track = pkgs.callPackage ./current-track { };
  i3dunst-toggle = pkgs.callPackage ./i3dunst-toggle { };
  bluetooth-battery = pkgs.callPackage ./bluetooth-battery { };
  i3lock-fancy = pkgs.callPackage ./i3lock-fancy { };
}
