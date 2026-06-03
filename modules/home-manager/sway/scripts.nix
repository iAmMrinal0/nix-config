{ pkgs, ... }:

{
  home.packages = (with pkgs.scripts; [
    current-track
    i3dunst-toggle
    bluetooth-battery
    swaylock-custom
  ]) ++ [ pkgs.rofi-power-menu ];
  # rofi-autorandr stays X11-only and lives with the i3 module. Multi-monitor
  # switching under sway is handled automatically by kanshi based on output
  # identifiers — no manual switcher needed in most cases.
}
