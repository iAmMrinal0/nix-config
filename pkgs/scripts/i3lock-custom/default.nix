{ pkgs, lib, stdenv }:

let 
  lockImagePath = builtins.path { 
    path = ./lock.png; 
    name = "lock.png"; 
  };
in
pkgs.writeShellScriptBin "i3lock-custom" ''
  ${pkgs.maim}/bin/maim --hidecursor /tmp/screen.png
  ${pkgs.imagemagick}/bin/magick convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png
  [[ -f ${lockImagePath} ]] && ${pkgs.imagemagick}/bin/convert /tmp/screen.png ${lockImagePath} -gravity center -composite -matte /tmp/screen_pixel.png
  rm -f /tmp/screen.png
  ${pkgs.i3lock}/bin/i3lock -u -i /tmp/screen_pixel.png
  ${pkgs.playerctl}/bin/playerctl pause
  ${pkgs.xorg.xset}/bin/xset dpms force off
''
