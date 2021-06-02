{ pkgs, ... }:

pkgs.writeShellScript "dunstNotifToggle" ''

toggle() {
  status=$(${pkgs.dunst}/bin/dunstctl is-paused)
  if [ "$status" = "true" ]
    then echo 
  else
    echo 
  fi
}

case $BLOCK_BUTTON in
    3) ${pkgs.dunst}/bin/dunstctl set-paused toggle ;; # right click
    *) toggle ;;
esac
''
