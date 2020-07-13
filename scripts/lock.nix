{ pkgs, ... }:

with pkgs;

let lock = ../locks/lock.png;
in
writeShellScript "lock" ''
${scrot}/bin/scrot /tmp/screen.png
${imagemagick}/bin/convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png
[[ -f ${lock} ]] && ${imagemagick}/bin/convert /tmp/screen.png ${lock} -gravity center -composite -matte /tmp/screen.png
${i3lock}/bin/i3lock -u -i /tmp/screen.png
rm /tmp/screen.png
${pulseaudio}/bin/playerctl pause
${xorg.xset}/bin/xset dpms force off
''
