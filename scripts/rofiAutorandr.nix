{ pkgs, ... }:

pkgs.writeShellScript "rofiAutorandr" ''
  layout=$(${pkgs.autorandr}/bin/autorandr | rofi -dmenu -p "Layout")
  ${pkgs.autorandr}/bin/autorandr --load $layout
''
