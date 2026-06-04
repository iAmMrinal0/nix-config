{ writeShellScriptBin, gamescope, flatpak }:

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
# Defaults to 1080p60 — UHD 620 doesn't have enough headroom to handle
# 1440p120 HW decode + gamescope compositing without stutter on this
# laptop (VCS+RCS sustained near saturation, see gpu sample logs). Bump
# back up per-launch via env vars: GFN_W, GFN_H, GFN_R.

writeShellScriptBin "gfn" ''
  W="''${GFN_W:-1920}"
  H="''${GFN_H:-1080}"
  R="''${GFN_R:-60}"

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
