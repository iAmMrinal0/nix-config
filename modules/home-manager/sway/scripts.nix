{ pkgs, ... }:

{
  home.packages = (with pkgs.my.scripts; [
    current-track
    i3dunst-toggle
    bluetooth-battery
    swaylock-custom
    # In PATH as well as autostart, so a Cryptomator that crashed mid-session
    # can be restarted (mount sweep included) without waiting for a relogin.
    cryptomator-launch
  ]) ++ [ pkgs.rofi-power-menu ];
  # rofi-autorandr stays X11-only and lives with the i3 module. Multi-monitor
  # switching under sway is handled automatically by kanshi based on output
  # identifiers — no manual switcher needed in most cases.
}
