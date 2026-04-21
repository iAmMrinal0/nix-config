{ pkgs }:

{
  rofi-autorandr = pkgs.callPackage ./rofi-autorandr { };
  rofi-tailscale-exit-node = pkgs.callPackage ./rofi-tailscale-exit-node { };
  rofi-tailscale-account = pkgs.callPackage ./rofi-tailscale-account { };
  current-track = pkgs.callPackage ./current-track { };
  i3dunst-toggle = pkgs.callPackage ./i3dunst-toggle { };
  bluetooth-battery = pkgs.callPackage ./bluetooth-battery { };
  i3lock-custom = pkgs.callPackage ./i3lock-custom { };
}
