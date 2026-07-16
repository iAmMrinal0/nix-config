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
  # it. We grab a non-blocking lock on fd 9; the daemonized swaylock below
  # inherits the fd (its daemonize() only redirects stdout/stderr, it closes
  # nothing else — verified in swaylock main.c), so the lock stays held for
  # the entire lifetime of swaylock even though this script exits as soon as
  # the screen is locked. The kernel drops it when the last holder exits
  # (even on SIGKILL), so there's no stale state and no time window to
  # reason about. A lock trigger that arrives while the screen is already
  # locked fails flock -n and exits cleanly — safe, the screen is locked.
  # Crucially this NEVER silently drops a *wanted* lock the way the cooldown
  # did: if no swaylock is running (manual Mod+Ctrl+l, before-sleep on lid
  # close, idle timeout) flock succeeds and we lock. It only ever errs
  # toward "locked".
  #
  # Why this kills *stacked* locks: the bulk of a burst's triggers arrive
  # while the screen sits locked waiting for the user, and the held lock
  # absorbs all of them. Only a straggler in the brief window right after
  # unlock could re-lock — and that re-locks (safe), it doesn't leave the
  # session exposed. (The *sequential* relock cascade had a different cause
  # — see the --daemonize comment below.)
  exec 9>"$RUNTIME_DIR/swaylock-custom.lock"
  if ! ${pkgs.util-linux}/bin/flock -n 9; then
    exit 0
  fi

  # Slim diagnostic log. This caught the 2026-07-16 cascade: sequential
  # relocks with parent=swayidle, ~8s apart — swayidle (running with -w) sat
  # blocked on our foreground swaylock for 9h, idle-notify events queued in
  # its Wayland socket, and the stale backlog replayed on unlock, relocking
  # once per drained event. Fixed by --daemonize below; the log stays while
  # we confirm the fix holds. Lives in XDG_RUNTIME_DIR (per-user tmpfs,
  # 0700) rather than a world-readable /tmp path. Safe to delete this block
  # after a few weeks cascade-free.
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
  # --scaling=fit (not swaylock's default of fill): the canvas is built to the
  # focused output's geometry with all text/QR anchored at the left edge (X=60).
  # fill scales-to-cover and crops the overflow centered, so any time the canvas
  # aspect ratio doesn't match the output's — most notably when the IPC query
  # above fails and SCREEN_W/H fall back to 1920x1080 on the 2560x1600 panel —
  # it shaves the sides and the left-anchored content disappears off-screen.
  # fit letterboxes instead of cropping; the bars are invisible on a pure-black
  # background, and the left edge is always preserved.
  # --daemonize: the parent swaylock exits 0 only once the compositor has
  # confirmed the session lock (daemonize() runs after the ext-session-lock
  # "locked" event — verified in swaylock main.c), so this script — and
  # therefore whoever spawned it — returns the moment the screen is actually
  # locked. This is what ends the sequential "unlock N times" cascade:
  # swayidle runs with -w and used to sit blocked in waitpid on our
  # foreground swaylock for the whole locked stretch (9h on 2026-07-16);
  # idle-notify events queued in its Wayland socket meanwhile and replayed
  # as a burst of stale relocks on unlock. It also gives before-sleep its
  # intended semantics: the sleep inhibitor is released exactly when the
  # lock is drawn instead of via logind's 5s inhibit timeout.
  if ${pkgs.swaylock}/bin/swaylock --daemonize \
    --image "$TMPDIR/lock.png" \
    --scaling fit \
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
    --bs-hl-color 00000000; then
    # Locked. Teardown (unpause dunst, delete the rendered image) must wait
    # for unlock, but nothing may block here — hand it to a background
    # waiter keyed on the same lockfile: the daemonized swaylock holds the
    # fd-9 flock until it exits, so a blocking flock on a fresh fd wakes
    # exactly at unlock. The waiter must first close its inherited fd 9 —
    # it's the same open file description swaylock holds, and keeping it
    # open would hold the lock forever (deadlocking the waiter and blocking
    # every future lock). It drops fd 10 again before running the teardown
    # commands, so the post-unlock window where a fresh lock attempt sees
    # the file locked stays microseconds wide.
    # Deleting TMPDIR here (not at unlock) would also be safe — swaylock
    # caches the image in memory at startup — but the waiter has to exist
    # for the dunst unpause anyway, so cleanup rides along with it and the
    # EXIT trap (which would fire the moment this script returns, i.e. at
    # lock time, not unlock) is cleared.
    trap - EXIT
    (
      exec 9>&-
      ${pkgs.util-linux}/bin/flock 10
      exec 10>&-
      ${pkgs.dunst}/bin/dunstctl set-paused false
      ${pkgs.coreutils}/bin/rm -rf "$TMPDIR"
    ) 10>"$RUNTIME_DIR/swaylock-custom.lock" &
  else
    # swaylock never locked — unpause dunst now; the EXIT trap cleans up.
    rc=$?
    ${pkgs.dunst}/bin/dunstctl set-paused false
    exit $rc
  fi
''
