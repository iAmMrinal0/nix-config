{ writeShellScriptBin, autorandr, rofi }:

writeShellScriptBin "rofi-autorandr" ''
  layout=$(${autorandr}/bin/autorandr --list | ${rofi}/bin/rofi -dmenu -p "Layout")
  ${autorandr}/bin/autorandr --load $layout
''
