{ pkgs, ... }:

with pkgs;
let wallpaper = fetchurl {
  url = "https://raw.githubusercontent.com/iAmMrinal0/dotfiles/master/wallpapers/kyloren.jpg";
  sha256 = "8ca65c8513cbca0fe3655e6e312837a16172da7d69c73f9c1849b14288b47537";
};
in
writeText "onAttachMonitor" ''
  ${feh}/bin/feh --bg-scale ${wallpaper}
''
