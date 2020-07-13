{ pkgs, ... }:

with pkgs;
let wallpaper = ../wallpapers/kyloren.jpg;
in
writeText "onAttachMonitor" ''
  ${feh}/bin/feh --bg-scale ${wallpaper}
''
