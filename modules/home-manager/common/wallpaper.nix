{ pkgs, ... }:

# wallpaper credits: https://github.com/gytis-ivaskevicius/high-quality-nix-content/blob/master/wallpapers/nix-glow-black.png
let wallpaper = ./wallpapers/nix-glow-black.png;
in pkgs.writeText "onAttachMonitor" ''
  ${pkgs.feh}/bin/feh --bg-scale ${wallpaper}
''
