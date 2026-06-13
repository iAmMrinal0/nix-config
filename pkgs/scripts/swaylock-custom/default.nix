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
in pkgs.writeShellScriptBin "swaylock-custom" ''
  set -u

  RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"

  # Single-instance guard via flock. This atomically replaces the old
  # `pgrep -x swaylock` check AND the 10-second cooldown that sat on top of
  # it. We grab a non-blocking lock on fd 9 and hold it for the entire
  # lifetime of swaylock; the kernel drops it when this process exits (even
  # on SIGKILL), so there's no stale state and no time window to reason
  # about. A lock trigger that arrives while the screen is already locked
  # fails flock -n and exits cleanly — safe, the screen is locked. Crucially
  # this NEVER silently drops a *wanted* lock the way the cooldown did: if no
  # swaylock is running (manual Mod+Ctrl+l, before-sleep on lid close, idle
  # timeout) flock succeeds and we lock. It only ever errs toward "locked".
  #
  # Why this kills the "unlock N times" cascade: the bulk of a burst's
  # triggers arrive while the screen sits locked waiting for the user, and
  # the held lock absorbs all of them. Only a straggler in the brief window
  # right after unlock could re-lock — and that re-locks (safe), it doesn't
  # leave the session exposed.
  exec 9>"$RUNTIME_DIR/swaylock-custom.lock"
  if ! ${pkgs.util-linux}/bin/flock -n 9; then
    exit 0
  fi

  # Slim diagnostic log, kept while we confirm flock ends the cascades.
  # If a cascade ever recurs WITH this guard in place it can't be stacking
  # (flock prevents that) — it means swaylock is exiting and being respawned
  # sequentially (e.g. dying on an evdi output modeset during the idle
  # power-off/resume cycle), and parent= names whoever relaunched it. Lives
  # in XDG_RUNTIME_DIR (per-user tmpfs, 0700) rather than a world-readable
  # /tmp path. Safe to delete this block after a few weeks cascade-free.
  LOG="$RUNTIME_DIR/swaylock-custom.log"
  PARENT_CMD=$(${pkgs.coreutils}/bin/cat /proc/$PPID/comm 2>/dev/null || echo unknown)
  ${pkgs.coreutils}/bin/printf '%s pid=%d ppid=%d parent=%s\n' \
    "$(${pkgs.coreutils}/bin/date +%Y-%m-%dT%H:%M:%S.%N)" "$$" "$PPID" "$PARENT_CMD" \
    >> "$LOG"

  ${pkgs.playerctl}/bin/playerctl pause 2>/dev/null || true

  TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d /tmp/swaylock-XXXXXX)
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

  # Get the first focused output's geometry from sway, fall back to the
  # first active output if we can't find a focused one. If the IPC doesn't
  # answer, the 1920x1080 default below kicks in and swaylock UPSCALES the
  # canvas on bigger outputs (huge text/QR) — it's a last resort, not a
  # sane default.
  read -r SCREEN_W SCREEN_H OUT_X OUT_Y < <(${pkgs.sway}/bin/swaymsg -t get_outputs 2>/dev/null \
    | ${pkgs.jq}/bin/jq -r '
        ([.[] | select(.active and .focused)] | first) // ([.[] | select(.active)] | first)
        | "\(.rect.width) \(.rect.height) \(.rect.x) \(.rect.y)"
      ' 2>/dev/null)
  SCREEN_W=''${SCREEN_W:-1920}
  SCREEN_H=''${SCREEN_H:-1080}
  OUT_X=''${OUT_X:-0}
  OUT_Y=''${OUT_Y:-0}

  # Full-screen black canvas sized to the focused output
  ${pkgs.imagemagick}/bin/magick -size "''${SCREEN_W}x''${SCREEN_H}" "xc:${bgColor}" "$TMPDIR/bg.png"

  # QR code — random rickroll URL each lock
  URLS=(${lib.concatMapStringsSep " " (u: ''"${u}"'') fortuneUrls})
  URL=''${URLS[$((RANDOM % ''${#URLS[@]}))]}
  ${pkgs.qrencode}/bin/qrencode \
    --output "$TMPDIR/qr.png" \
    --size 6 --margin 2 \
    --foreground=00ff7f --background=000000 \
    "$URL"

  X=60
  Y=60
  LINE=32
  QR_X=$X
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
  # Hide every variant of the unlock indicator (idle, typing, verifying,
  # wrong, clear, caps-lock). The lock-screen background image is the
  # entire UI; we don't want a circle hovering over it. Setting all
  # indicator colors to fully transparent (RRGGBB"00") makes every state
  # invisible.
  ${pkgs.swaylock}/bin/swaylock \
    --image "$TMPDIR/lock.png" \
    --color 000000 \
    --hide-keyboard-layout \
    --inside-color 00000000        --ring-color 00000000 \
    --inside-ver-color 00000000    --ring-ver-color 00000000 \
    --inside-wrong-color 00000000  --ring-wrong-color 00000000 \
    --inside-clear-color 00000000  --ring-clear-color 00000000 \
    --inside-caps-lock-color 00000000 --ring-caps-lock-color 00000000 \
    --text-color 00000000          --text-ver-color 00000000 \
    --text-wrong-color 00000000    --text-clear-color 00000000 \
    --text-caps-lock-color 00000000 \
    --line-color 00000000          --line-ver-color 00000000 \
    --line-wrong-color 00000000    --line-clear-color 00000000 \
    --line-caps-lock-color 00000000 \
    --separator-color 00000000     --key-hl-color 00000000 \
    --bs-hl-color 00000000
  ${pkgs.dunst}/bin/dunstctl set-paused false
''
