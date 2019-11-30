{ pkgs, lock, ... }:

with pkgs;

writeShellScript "shutdownMenu" (''

# Colors: FG (foreground), BG (background), HL (highlighted)
FG_COLOR="#bbbbbb"
BG_COLOR="#111111"
HLFG_COLOR="#111111"
HLBG_COLOR="#bbbbbb"
BORDER_COLOR="#222222"

# Options not related to colors
ROFI_TEXT="Operation:"
# ROFI_OPTIONS="-width -11 -location 3 -hide-scrollbar -bw 2"

# Whether to ask for user's confirmation
enable_confirmation=false

usage="$(basename "$0") [-h] [-c] -- display a menu for shutdown, reboot, lock etc.
where:
    -h  show this help text
    -c  ask for user confirmation
This script depends on:
  - systemd,
  - i3,
  - rofi."

# Parse CLI arguments
while getopts "hcp:" option; do
  case "$option" in
    h) echo "$usage"
       exit 0
       ;;
    c) enable_confirmation=true
       ;;
    *) exit 1
       ;;
  esac
done

# menu defined as an associative array
typeset -A menu

# Menu with keys/commands
menu=(
  [Shutdown]="systemctl poweroff"
  [Reboot]="systemctl reboot"
  [Hibernate]="sh ${lock} && systemctl hibernate"
  [Suspend]="sh ${lock} && systemctl suspend"
  [Halt]="systemctl halt"
  [Lock]="${lock}"
  [Logout]="i3-msg exit"
  [Cancel]=""
)
menu_nrows=$'' + ''{#menu[@]}

# Menu entries that may trigger a confirmation message
menu_confirm="Shutdown Reboot Hibernate Suspend Halt Logout"

rofi_colors="-bc $BORDER_COLOR -bg $BG_COLOR -fg $FG_COLOR -hlfg $HLFG_COLOR -hlbg $HLBG_COLOR"

launcher="${rofi}/bin/rofi -dmenu -i -lines $menu_nrows -p $ROFI_TEXT $rofi_colors $ROFI_OPTIONS"
selection="$(printf '%s\n' "$''+''{!menu[@]}" | sort | $launcher)"

function ask_confirmation() {
    confirmed=$(echo -e "Yes\nNo" | ${rofi}/bin/rofi -dmenu -i -lines 2 -p "$selection?" \
      $rofi_colors $ROFI_OPTIONS)
    [ "$confirmed" == "Yes" ] && confirmed=0

  if [ "$confirmed" == 0 ]; then
    i3-msg -q "exec $'' + ''{menu[$''+''{selection}]}"
  fi
}

if [[ $? -eq 0 && ! -z $selection ]]; then
  if [[ "$enable_confirmation" = true && \
        $menu_confirm =~ (^|[[:space:]])"$selection"($|[[:space:]]) ]]; then
    ask_confirmation
  else
    i3-msg -q "exec $'' + ''{menu[$''+''{selection}]}"
  fi
fi
'')
