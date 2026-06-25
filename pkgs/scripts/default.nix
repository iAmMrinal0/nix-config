{ pkgs }:

{
  rofi-autorandr = pkgs.callPackage ./rofi-autorandr { };
  rofi-kanshi = pkgs.callPackage ./rofi-kanshi { };
  rofi-tailscale-exit-node = pkgs.callPackage ./rofi-tailscale-exit-node { };
  rofi-tailscale-account = pkgs.callPackage ./rofi-tailscale-account { };
  current-track = pkgs.callPackage ./current-track { };
  i3dunst-toggle = pkgs.callPackage ./i3dunst-toggle { };
  bluetooth-battery = pkgs.callPackage ./bluetooth-battery { };
  mic-mute-toggle = pkgs.callPackage ./mic-mute-toggle { };
  i3lock-custom = pkgs.callPackage ./i3lock-custom { };
  gfn = pkgs.callPackage ./gfn { };
  garmin-sdk-manager = pkgs.callPackage ./garmin-sdk-container { };
  swaylock-custom = pkgs.callPackage ./swaylock-custom { };
}
