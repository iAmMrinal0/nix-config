{ pkgs }:

let
  i3lock-custom-pkg = pkgs.callPackage ./i3lock-custom { };
in
{
  rofi-autorandr = pkgs.callPackage ./rofi-autorandr { };
  current-track = pkgs.callPackage ./current-track { };
  i3dunst-toggle = pkgs.callPackage ./i3dunst-toggle { };
  bluetooth-battery = pkgs.callPackage ./bluetooth-battery { };
  i3lock-custom = i3lock-custom-pkg;
  shutdown-menu = pkgs.callPackage ./shutdown-menu { 
    i3lock-custom = i3lock-custom-pkg;
  };
}
