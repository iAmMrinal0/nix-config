{ pkgs, ... }:

with pkgs;

let lock = ../locks/lock.png;
in
writeShellScript "lock" ''
${maim}/bin/maim --hidecursor /tmp/screen.png
${imagemagick}/bin/convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png
[[ -f ${lock} ]] && ${imagemagick}/bin/convert /tmp/screen.png ${lock} -gravity center -composite -matte /tmp/screen_pixel.png
rm -f /tmp/screen.png
${i3lock}/bin/i3lock -u -i /tmp/screen_pixel.png
${playerctl}/bin/playerctl pause
${xorg.xset}/bin/xset dpms force off
''
