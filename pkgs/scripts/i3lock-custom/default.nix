{ pkgs, lib, stdenv }:

let
  # Random URLs encoded in the lockscreen QR. All roads lead to Rick.
  fortuneUrls = [
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    "https://youtu.be/dQw4w9WgXcQ"
    "https://m.youtube.com/watch?v=dQw4w9WgXcQ"
    "https://www.youtube.com/embed/dQw4w9WgXcQ"
    "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"
    "https://music.youtube.com/watch?v=dQw4w9WgXcQ"
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=43s"
    "https://www.youtube.com/watch?v=oHg5SJYRHA0"
  ];
  font = "${pkgs.iosevka}/share/fonts/truetype/Iosevka-Bold.ttf";
  fgColor = "#00ff7f"; # phosphor green
  bgColor = "#000000"; # pure black
in pkgs.writeShellScriptBin "i3lock-custom" ''
  set -u
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

  ${pkgs.playerctl}/bin/playerctl pause 2>/dev/null || true

  TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d /tmp/i3lock-XXXXXX)
  trap "${pkgs.coreutils}/bin/rm -rf $TMPDIR" EXIT

  USER_NAME=$(${pkgs.coreutils}/bin/whoami)
  HOST_NAME=$(${pkgs.inetutils}/bin/hostname)
  KERNEL=$(${pkgs.coreutils}/bin/uname -r)
  if [[ -r /etc/os-release ]]; then
    OS_NAME=$(${pkgs.gnugrep}/bin/grep -E '^NAME=' /etc/os-release | ${pkgs.gnused}/bin/sed -E 's/^NAME="?([^"]*)"?/\1/')
    OS_VERSION=$(${pkgs.gnugrep}/bin/grep -E '^VERSION_ID=' /etc/os-release | ${pkgs.gnused}/bin/sed -E 's/^VERSION_ID="?([^"]*)"?/\1/')
  else
    OS_NAME="Linux"
    OS_VERSION=""
  fi

  # Full-screen black canvas
  SCREEN_SIZE=$(${pkgs.xorg.xdpyinfo}/bin/xdpyinfo | ${pkgs.gawk}/bin/awk '/dimensions:/ {print $2; exit}')
  SCREEN_SIZE=''${SCREEN_SIZE:-1920x1080}
  ${pkgs.imagemagick}/bin/magick -size "$SCREEN_SIZE" "xc:${bgColor}" "$TMPDIR/bg.png"

  # Focused monitor's top-left for placing the static text + QR
  read -r OUT_X OUT_Y < <(${pkgs.i3}/bin/i3-msg -t get_outputs 2>/dev/null \
    | ${pkgs.jq}/bin/jq -r '[.[] | select(.active and .focused)] | .[0].rect | "\(.x // 0) \(.y // 0)"' 2>/dev/null)
  OUT_X=''${OUT_X:-0}
  OUT_Y=''${OUT_Y:-0}

  # QR code — random rickroll URL each lock
  URLS=(${lib.concatMapStringsSep " " (u: ''"${u}"'') fortuneUrls})
  URL=''${URLS[$((RANDOM % ''${#URLS[@]}))]}
  ${pkgs.qrencode}/bin/qrencode \
    --output "$TMPDIR/qr.png" \
    --size 6 --margin 2 \
    --foreground=00ff7f --background=000000 \
    "$URL"

  X=$((OUT_X + 60))
  Y=$((OUT_Y + 60))
  LINE=32
  QR_X=$((X))
  QR_Y=$((Y + LINE * 9))

  ${pkgs.imagemagick}/bin/magick "$TMPDIR/bg.png" \
    -font "${font}" -pointsize 22 -fill '${fgColor}' \
    -annotate +''${X}+''${Y}                    "$OS_NAME $OS_VERSION $HOST_NAME tty1 (Linux $KERNEL)" \
    -annotate +''${X}+$((Y + LINE * 3))         "$HOST_NAME login: $USER_NAME" \
    -annotate +''${X}+$((Y + LINE * 4))         "Password: _" \
    -annotate +''${X}+$((Y + LINE * 7))         "(or scan the QR code to unlock)" \
    "$TMPDIR/qr.png" -geometry +''${QR_X}+''${QR_Y} -composite \
    "$TMPDIR/lock.png"

  ${pkgs.dunst}/bin/dunstctl set-paused true
  ${pkgs.i3lock}/bin/i3lock -e -u -c 000000 -i "$TMPDIR/lock.png" --nofork
  ${pkgs.dunst}/bin/dunstctl set-paused false
''
