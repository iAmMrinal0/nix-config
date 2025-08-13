{ pkgs, lib, stdenv }:

let
  lockImagePath = builtins.path {
    path = ./lock.png;
    name = "lock.png";
  };
in pkgs.writeShellScriptBin "i3lock-custom" ''
  # tiny sleep to avoid race between xautolock and xss-lock
  sleep 0.2

  # exit if i3lock is already running
  if ${pkgs.procps}/bin/pgrep -x i3lock >/dev/null; then
    exit 0
  fi

  # exit if DPMS is already off (screen appears off/locked)
  dpms_status=$(${pkgs.xorg.xset}/bin/xset -q | ${pkgs.gnugrep}/bin/grep "Monitor is" | ${pkgs.gawk}/bin/awk '{print $3}')
  if [[ "$dpms_status" == "Off" ]]; then
    exit 0
  fi

  ${pkgs.playerctl}/bin/playerctl pause
  ${pkgs.maim}/bin/maim --hidecursor /tmp/screen.png
  ${pkgs.imagemagick}/bin/magick /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png
  ${pkgs.imagemagick}/bin/magick /tmp/screen.png ${lockImagePath} -gravity center -composite -alpha set /tmp/screen_pixel.png
  rm -f /tmp/screen.png
  ${pkgs.dunst}/bin/dunstctl set-paused true
  ${pkgs.i3lock}/bin/i3lock -u -i /tmp/screen_pixel.png --nofork
  ${pkgs.dunst}/bin/dunstctl set-paused false
''
