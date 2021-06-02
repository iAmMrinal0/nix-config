{ pkgs, ... }:

let wallpaper = ../wallpapers/kyloren.jpg;
in pkgs.writeText "onAttachMonitor" ''
  ${pkgs.feh}/bin/feh --bg-scale ${wallpaper}
''
