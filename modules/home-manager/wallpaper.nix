{ pkgs, ... }:

# Bing-wallpaper-style rotating scenery backgrounds for the sway (Wayland)
# session. awww (the renamed swww; nixpkgs now exposes it as `pkgs.awww`,
# binaries awww / awww-daemon) owns the root surface, replacing the static
# swaybg exec that used to live in sway/config.nix.
#
# Three concerns, deliberately split so rotation is always instant:
#   * wallpaper-next  (rotate) — pick a random cached image and hand it to awww
#     with a fade. No network, returns immediately. Run by wallpaper.service at
#     login and wallpaper.timer every 3h. This is the "change my wallpaper now"
#     command.
#   * wallpaper-apply (re-assert) — repaint the image wallpaper-next last
#     picked, on every output, without rotating. Driven by kanshi's per-profile
#     exec hook (see kanshi.nix) so an output that hotplugs in under a connector
#     name awww has no cache entry for still gets a wallpaper immediately
#     instead of coming up bare until the next 3h tick.
#   * wallpaper-fetch (top up) — download fresh sceneries from Bing + Wallhaven
#     into the cache, prune, then rotate into one. Slow (network), so it is
#     driven only by its own timer (shortly after login + daily) and never
#     blocks login, `nh os switch`, or an interactive `wallpaper-next`.
#
# The scripts themselves live in wallpaper-scripts.nix so kanshi.nix can
# reference wallpaper-apply's store path.
#
# Everything is scoped to sway-session.target, so the i3 (X11) pick is
# unaffected — it keeps the static feh wallpaper (see common/wallpaper.nix).
#
# Cold first login: wallpaper-next paints the committed nix-glow-black.png
# fallback (cache empty), then ~1 min later wallpaper-fetch fills the pool and
# rotates into a real scenery.

let
  scripts = import ./wallpaper-scripts.nix { inherit pkgs; };
  inherit (scripts) rotate apply fetch;

in {
  # awww (renamed swww) for manual `awww img ...` overrides; the scripts expose
  # `wallpaper-next` (instant rotate), `wallpaper-apply` (repaint the current
  # one everywhere) and `wallpaper-fetch` (refresh the pool) on PATH.
  home.packages = [ pkgs.awww rotate apply fetch ];

  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
      # Only meaningful under Wayland; never trip under the i3/X11 pick.
      ConditionEnvironment = "WAYLAND_DISPLAY";
      # Ride out the env-propagation lag at session start (cf. kanshi.nix):
      # the default 5-in-10s budget with 100ms RestartSec exhausts instantly.
      StartLimitBurst = 10;
      StartLimitIntervalSec = 30;
    };
    Service = {
      Type = "simple";
      # Clear a stale swaybg left over from a pre-awww session (removing its
      # sway exec doesn't kill the running process) — it would otherwise cover
      # awww's surface and the wallpaper would never appear to change. `-`
      # ignores pkill's exit 1 when there's nothing to kill.
      ExecStartPre = "-${pkgs.procps}/bin/pkill -x swaybg";
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  # Rotate (fast): paint at login + every 3h.
  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Rotate the desktop wallpaper";
      PartOf = [ "sway-session.target" ];
      After = [ "awww-daemon.service" ];
      Requires = [ "awww-daemon.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${rotate}/bin/wallpaper-next";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  systemd.user.timers.wallpaper = {
    Unit = {
      Description = "Rotate the desktop wallpaper every few hours";
      PartOf = [ "sway-session.target" ];
    };
    Timer = {
      OnActiveSec = "3h";
      OnUnitActiveSec = "3h";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  # Fetch (slow, network): NOT WantedBy the target — only its timer starts it,
  # so login / `nh os switch` / a manual `wallpaper-next` never block on it.
  systemd.user.services.wallpaper-fetch = {
    Unit = {
      Description = "Download fresh wallpaper sceneries (Bing + Wallhaven)";
      After = [ "awww-daemon.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${fetch}/bin/wallpaper-fetch";
      # First run pulls ~90 Wallhaven images; be generous so it isn't reaped.
      TimeoutStartSec = 900;
    };
  };

  systemd.user.timers.wallpaper-fetch = {
    Unit = {
      Description = "Refresh the wallpaper pool (shortly after login + daily)";
      PartOf = [ "sway-session.target" ];
    };
    Timer = {
      OnActiveSec = "1min";
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
