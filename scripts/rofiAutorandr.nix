{ pkgs, ... }:

with pkgs;

writeShellScript "rofiAutorandr" ''
layout=$(${autorandr}/bin/autorandr | rofi -dmenu -p "Layout")
${autorandr}/bin/autorandr --load $layout
''
