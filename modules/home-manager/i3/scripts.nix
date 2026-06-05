{ pkgs, ... }:

{
  home.packages = (with pkgs.my.scripts; [
    rofi-autorandr
    current-track
    i3dunst-toggle
    bluetooth-battery
    i3lock-custom
  ]) ++ [ pkgs.rofi-power-menu ];
}
