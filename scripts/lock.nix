{ pkgs, ... }:

let lock = ../locks/lock.png;
in pkgs.writeShellScript "lock" ''
  ${pkgs.maim}/bin/maim --hidecursor /tmp/screen.png
  ${pkgs.imagemagick}/bin/convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png
  [[ -f ${lock} ]] && ${pkgs.imagemagick}/bin/convert /tmp/screen.png ${lock} -gravity center -composite -matte /tmp/screen_pixel.png
  rm -f /tmp/screen.png
  ${pkgs.i3lock}/bin/i3lock -u -i /tmp/screen_pixel.png
  ${pkgs.playerctl}/bin/playerctl pause
  ${pkgs.xorg.xset}/bin/xset dpms force off
''
