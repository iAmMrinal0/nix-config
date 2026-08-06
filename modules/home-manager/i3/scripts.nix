{ pkgs, ... }:

{
  home.packages = (with pkgs.my.scripts; [
    rofi-autorandr
    current-track
    i3dunst-toggle
    bluetooth-battery
    i3lock-custom
    # In PATH as well as autostart, so a Cryptomator that crashed mid-session
    # can be restarted (mount sweep included) without waiting for a relogin.
    cryptomator-launch
  ]) ++ [ pkgs.rofi-power-menu ];
}
