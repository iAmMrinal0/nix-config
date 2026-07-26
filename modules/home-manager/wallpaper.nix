{ pkgs, ... }:

# Bing-wallpaper-style rotating scenery backgrounds for the sway (Wayland)
# session. awww (the renamed swww; nixpkgs now exposes it as `pkgs.awww`,
# binaries awww / awww-daemon) owns the root surface, replacing the static
# swaybg exec that used to live in sway/config.nix.
#
# Two concerns, deliberately split so rotation is always instant:
#   * wallpaper-next  (rotate) — pick a random cached image and hand it to awww
#     with a fade. No network, returns immediately. Run by wallpaper.service at
#     login and wallpaper.timer every 3h. This is the "change my wallpaper now"
#     command.
#   * wallpaper-fetch (top up) — download fresh sceneries from Bing + Wallhaven
#     into the cache, prune, then rotate into one. Slow (network), so it is
#     driven only by its own timer (shortly after login + daily) and never
#     blocks login, `nh os switch`, or an interactive `wallpaper-next`.
#
# Everything is scoped to sway-session.target, so the i3 (X11) pick is
# unaffected — it keeps the static feh wallpaper (see common/wallpaper.nix).
#
# Cold first login: wallpaper-next paints the committed nix-glow-black.png
# fallback (cache empty), then ~1 min later wallpaper-fetch fills the pool and
# rotates into a real scenery.

let
  # Offline fallback — same image the old static swaybg/feh setup used.
  fallback = ./common/wallpapers/nix-glow-black.png;

  # Pool sizing, tuned for variety (~100 images). Bing only ever supplies a
  # handful (its API exposes the last 8 days), so the bulk is Wallhaven. The
  # daily prune keeps the newest poolMax by mtime; because fresh Bing images
  # keep arriving, they slowly age Wallhaven out — when the Wallhaven stock
  # dips below whMin the fetch tops it back up to whTarget, so variety
  # self-heals without re-downloading on every run.
  poolMax = 110;   # hard cap kept on disk (prune target)
  whTarget = 90;   # Wallhaven images to maintain
  whMin = 60;      # refill Wallhaven once its count drops below this

  # errexit off in both scripts on purpose: individual paint/fetch steps are
  # best-effort and must not abort the whole run.

  rotate = pkgs.writeShellApplication {
    name = "wallpaper-next";
    runtimeInputs = with pkgs; [ awww coreutils findutils ];
    text = ''
      set +e
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpapers"
      fallback="${fallback}"

      # awww's IPC socket is named "<WAYLAND_DISPLAY>-awww-daemon.sock". When
      # invoked from a context whose WAYLAND_DISPLAY is missing or stale (e.g. a
      # tmux pane — tmux doesn't propagate WAYLAND_DISPLAY into panes), point at
      # the display of the daemon that is actually running instead of failing.
      runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      if [ ! -S "$runtime/''${WAYLAND_DISPLAY:-wayland-0}-awww-daemon.sock" ]; then
        sock="$(find "$runtime" -maxdepth 1 -name '*-awww-daemon.sock' 2>/dev/null | head -n1)"
        if [ -n "$sock" ]; then
          base="$(basename "$sock")"
          export WAYLAND_DISPLAY="''${base%-awww-daemon.sock}"
        fi
      fi

      # Wait for the daemon to accept connections (short — it's a systemd
      # service ordered before us; this only rides out the WAYLAND_DISPLAY
      # env-import lag at session start).
      ready=""
      for _ in $(seq 1 10); do
        if awww query >/dev/null 2>&1; then ready=1; break; fi
        sleep 1
      done
      if [ -z "$ready" ]; then
        echo "wallpaper-next: awww-daemon not reachable — is the sway session up?" >&2
        echo "  try: systemctl --user restart awww-daemon.service" >&2
        exit 1
      fi

      # Random cached image, else the offline fallback.
      img="$(find "$cache" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null \
        | shuf -n1)"
      if [ -z "$img" ]; then img="$fallback"; fi

      if awww img "$img" \
        --resize crop \
        --transition-type any \
        --transition-duration 2 \
        --transition-fps 60; then
        echo "wallpaper-next: set $img"
      else
        echo "wallpaper-next: awww img failed for $img" >&2
        exit 1
      fi
    '';
  };

  fetch = pkgs.writeShellApplication {
    name = "wallpaper-fetch";
    runtimeInputs = with pkgs; [ curl jq coreutils findutils rotate ];
    text = ''
      set +e
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpapers"
      mkdir -p "$cache"

      # Download $1 to $2 atomically; leaves no partial file on failure.
      dl() {
        if curl -fsSL --connect-timeout 8 --max-time 25 -o "$2.tmp" "$1"; then
          mv "$2.tmp" "$2"; echo "  + $(basename "$2")" >&2
        else
          rm -f "$2.tmp"; return 1
        fi
      }

      echo "wallpaper-fetch: updating pool in $cache" >&2

      # Bing: last 8 daily images at max (UHD) resolution. No-op once cached.
      meta="$(curl -fsSL --connect-timeout 8 --max-time 20 \
        'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US')"
      if [ -n "$meta" ]; then
        while IFS=$'\t' read -r base end; do
          if [ -z "$base" ]; then continue; fi
          out="$cache/bing-$end.jpg"
          if [ -s "$out" ]; then continue; fi
          dl "https://www.bing.com''${base}_UHD.jpg" "$out"
        done < <(printf '%s' "$meta" | jq -r '.images[] | "\(.urlbase)\t\(.enddate)"')
      fi

      # Wallhaven: refill only when our Wallhaven stock is low, then paginate
      # up to whTarget. General category, SFW, at least QHD, landscape/nature.
      # A per-run random seed pins the random ordering across pages so we walk
      # distinct results instead of re-rolling (and re-fetching) page 1 each
      # time. 24 results/page, so whTarget is reached in a few pages; the
      # per-file `-s` skip dedupes anything already cached.
      whcount() { find "$cache" -maxdepth 1 -type f -name 'wh-*' | wc -l; }
      if [ "$(whcount)" -lt ${toString whMin} ]; then
        seed="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c6 || true)"
        page=1
        while [ "$(whcount)" -lt ${toString whTarget} ] && [ "$page" -le 8 ]; do
          wh="$(curl -fsSL --connect-timeout 8 --max-time 20 \
            "https://wallhaven.cc/api/v1/search?categories=100&purity=100&sorting=random&seed=$seed&atleast=2560x1440&q=landscape+nature&page=$page")"
          if [ -z "$wh" ]; then break; fi
          batch="$(printf '%s' "$wh" | jq -r '.data[].path')"
          if [ -z "$batch" ]; then break; fi
          while read -r u; do
            if [ -z "$u" ]; then continue; fi
            out="$cache/wh-$(basename "$u")"
            if [ -s "$out" ]; then continue; fi
            dl "$u" "$out"
          done < <(printf '%s' "$batch")
          page=$((page + 1))
        done
      fi

      # Prune to the newest ${toString poolMax} by mtime.
      while read -r old; do
        [ -n "$old" ] && rm -f "$old"
      done < <(find "$cache" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | tail -n +$((${toString poolMax} + 1)) | cut -d' ' -f2-)

      # Show a freshly-cached scenery now (no-op / harmless error if no daemon).
      wallpaper-next || true
    '';
  };

in {
  # awww (renamed swww) for manual `awww img ...` overrides; the scripts expose
  # `wallpaper-next` (instant rotate) and `wallpaper-fetch` (refresh the pool)
  # on PATH.
  home.packages = [ pkgs.awww rotate fetch ];

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
