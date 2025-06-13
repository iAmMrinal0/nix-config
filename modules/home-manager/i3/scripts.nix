{ pkgs, ... }:

{
  home.packages = with pkgs.scripts; [
    rofi-autorandr
    shutdown-menu
    current-track
    i3dunst-toggle
    bluetooth-battery
    i3lock-fancy
  ];
}
