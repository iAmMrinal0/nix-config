{ pkgs, ... }:

pkgs.writeShellScriptBin "rofi-autorandr" ''
  layout=$(${pkgs.autorandr}/bin/autorandr --list | rofi -dmenu -p "Layout")
  ${pkgs.autorandr}/bin/autorandr --load $layout --skip-option crtc
''
