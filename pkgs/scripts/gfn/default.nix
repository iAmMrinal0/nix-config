{ writeShellScriptBin, gamescope, flatpak, jq, gawk, sway, i3, xrandr
, width ? 1920, height ? 1080, refresh ? 60 }:

# Launcher for NVIDIA GeForce NOW (Flatpak). The SteamDeck build of the
# app expects a gamescope-0 Wayland socket and ships with
# ENABLE_GAMESCOPE=1 / ENABLE_GAMESCOPE_HDR=1 baked into the Flatpak env,
# so we wrap the flatpak invocation in gamescope.
#
# Backend is picked at launch from the session type, because gamescope's
# own probe gets it wrong nested in a desktop session (it lands on
# `headless` when DRM is owned by the compositor):
#   - X11 (i3): `sdl` — gamescope nests as a plain window via SDL.
#   - Wayland session present: `wayland` — nests via the parent
#     compositor's socket.
#
# Resolution: env (GFN_W/H/R) > focused-output auto-detect > per-host default.
# Query tools are referenced by store path — xrandr isn't otherwise installed.

writeShellScriptBin "gfn" ''
  dw="" dh="" dr=""
  if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
    d=$(${sway}/bin/swaymsg -t get_outputs 2>/dev/null \
      | ${jq}/bin/jq -r 'first(.[] | select(.focused)) | "\(.current_mode.width) \(.current_mode.height) \(.current_mode.refresh)"' 2>/dev/null)
    read -r dw dh dmhz <<< "$d"
    [ -n "$dmhz" ] && dr=$(( (dmhz + 500) / 1000 ))   # sway reports mHz
  else
    out=$(${i3}/bin/i3-msg -t get_workspaces 2>/dev/null \
      | ${jq}/bin/jq -r 'first(.[] | select(.focused)).output' 2>/dev/null)
    if [ -n "$out" ]; then
      d=$(${xrandr}/bin/xrandr --current 2>/dev/null | ${gawk}/bin/awk -v o="$out" '
        $1==o && $2=="connected" {g=1; next}
        $2=="connected" || $2=="disconnected" {g=0}
        g && /\*/ {
          for (i=2; i<=NF; i++) if ($i ~ /\*/) { gsub(/[*+]/, "", $i); r=$i }
          split($1, a, "x"); print a[1], a[2], int(r+0.5); exit
        }')
      read -r dw dh dr <<< "$d"
    fi
  fi

  W="''${GFN_W:-''${dw:-${toString width}}}"
  H="''${GFN_H:-''${dh:-${toString height}}}"
  R="''${GFN_R:-''${dr:-${toString refresh}}}"

  if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
    BACKEND=wayland
  else
    BACKEND=sdl
  fi

  exec ${gamescope}/bin/gamescope \
    --backend "$BACKEND" \
    -W "$W" -H "$H" -r "$R" -f \
    -- ${flatpak}/bin/flatpak run com.nvidia.geforcenow
''
