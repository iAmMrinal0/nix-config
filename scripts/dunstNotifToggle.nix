{ pkgs, ... }:

pkgs.writeShellScript "dunstNotifToggle" ''
PARENT_BAR="bottom"
PARENT_BAR_PID=$(${pkgs.procps}/bin/pgrep -a "polybar" | ${pkgs.gnugrep}/bin/grep "$PARENT_BAR" | ${pkgs.coreutils}/bin/cut -d" " -f1)

update_hooks() {
    polybar-msg -p "$1" hook dunst "$2" 1>/tmp/error 2>&1
}

if [ "$1" = "on" ];
then
    update_hooks "$PARENT_BAR_PID" 1
    ${pkgs.psmisc}/bin/killall -SIGUSR2 .dunst-wrapped
else
    update_hooks "$PARENT_BAR_PID" 2
    ${pkgs.psmisc}/bin/killall -SIGUSR1 .dunst-wrapped
fi
''
