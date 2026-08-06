{ pkgs }:

# The wallpaper scripts, factored out of wallpaper.nix so kanshi.nix can
# reference `apply`'s store path directly (see the hotplug hook there). NOT a
# home-manager module — it's a plain function returning derivations, and
# modules/home-manager/default.nix imports its modules explicitly, so this file
# is never picked up as one.

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

  # errexit off in all three scripts on purpose: individual paint/fetch steps
  # are best-effort and must not abort the whole run.

  # Where wallpaper-next records the image it painted, so wallpaper-apply can
  # re-assert the SAME one instead of rotating. Deliberately kept OUT of the
  # image pool ($cache) so wallpaper-fetch's prune (which walks every file in
  # there by mtime) can never see it, and so it doesn't eat a poolMax slot.
  stateFile = ''
    state="''${XDG_STATE_HOME:-$HOME/.local/state}"
    current="$state/wallpaper-current"
  '';

  # Shared by wallpaper-next and wallpaper-apply: find the daemon, then wait
  # for it.
  #
  # awww's IPC socket is named "<WAYLAND_DISPLAY>-awww-daemon.sock". When
  # invoked from a context whose WAYLAND_DISPLAY is missing or stale (e.g. a
  # tmux pane — tmux doesn't propagate WAYLAND_DISPLAY into panes), point at
  # the display of the daemon that is actually running instead of failing.
  awwwConnect = ''
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
      echo "$0: awww-daemon not reachable — is the sway session up?" >&2
      echo "  try: systemctl --user restart awww-daemon.service" >&2
      exit 1
    fi
  '';

  rotate = pkgs.writeShellApplication {
    name = "wallpaper-next";
    runtimeInputs = with pkgs; [ awww coreutils findutils ];
    text = ''
      set +e
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpapers"
      fallback="${fallback}"
      ${stateFile}
      ${awwwConnect}

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
        # Record the pick so wallpaper-apply can re-assert this exact image on
        # an output hotplug without rotating to a different one.
        mkdir -p "$state" && printf '%s\n' "$img" > "$current"
      else
        echo "wallpaper-next: awww img failed for $img" >&2
        exit 1
      fi
    '';
  };

  # Re-assert the current wallpaper on every output. Run from kanshi's per-
  # profile exec hook (see kanshi.nix), i.e. on login, dock hotplug, resume
  # (wakeOutputs' kanshictl reload) and manual rofi-kanshi switches.
  #
  # Why this is needed at all: awww keys its per-output cache by connector
  # NAME, and a DP-MST/USB-C dock re-enumerates its monitor under a fresh name
  # on each replug (observed on betazed: DP-2 → DP-3 → DP-4, which is also why
  # kanshi's criteria match on EDID instead). For a name awww has never seen
  # there is no cache entry to restore, so the head comes up with no wallpaper
  # at all — "failed to read cache file" in awww-daemon's log — and stays bare
  # until wallpaper.timer's next 3h tick.
  #
  # Deliberately NOT wallpaper-next: this fires on every resume and dock
  # event, and rotating there would reshuffle the wallpaper constantly.
  apply = pkgs.writeShellApplication {
    name = "wallpaper-apply";
    runtimeInputs = with pkgs; [ awww coreutils findutils gnugrep gnused jq sway ];
    text = ''
      set +e
      fallback="${fallback}"
      ${stateFile}
      ${awwwConnect}

      # Whatever wallpaper-next last painted.
      img="$(cat "$current" 2>/dev/null)"

      # No state file yet — first run after this landed, before any rotate has
      # recorded one (note HM restarts kanshi on config change, so this path
      # runs on the very rebuild that installs it). Ask the daemon what it is
      # already showing instead of blowing a perfectly good scenery away with
      # the committed fallback. `awww query` prints one line per output:
      #   "<name>: <WxH>, scale: <n>, currently displaying: image: <path>"
      # A shape change here just falls through to $fallback below.
      if [ ! -s "$img" ]; then
        img="$(awww query 2>/dev/null \
          | sed -n 's/.*currently displaying: image: //p' | head -n1)"
      fi

      # Still nothing: cold daemon, an output showing a solid colour rather than
      # an image, or a state file naming a file the daily prune has deleted.
      if [ ! -s "$img" ]; then img="$fallback"; fi

      # awww learns about a new output from the wayland registry, independently
      # of any img command — painting before it has seen the head is a silent
      # no-op, which is exactly the hotplug race this script exists to close
      # (kanshi runs exec straight after applying the profile, so the modeset
      # may still be settling). Wait until every output sway reports active is
      # one awww knows about.
      #
      # Parsing `awww query`'s text form ("<name>: <w>x<h>, ...") rather than
      # -j: the name is the first colon-delimited field in every swww/awww
      # release so far. If that ever changes shape the loop simply times out
      # and we paint anyway — a parse break degrades to the old behaviour
      # instead of to never painting.
      # Process substitution (not a pipe) so $missing survives the loop — same
      # reason wallpaper-fetch reads its batches that way.
      for _ in $(seq 1 20); do
        known="$(awww query 2>/dev/null | sed 's/:.*//')"
        missing=""
        while read -r o; do
          if [ -z "$o" ]; then continue; fi
          if ! printf '%s\n' "$known" | grep -qx "$o"; then missing=1; fi
        done < <(swaymsg -t get_outputs --raw 2>/dev/null \
          | jq -r '.[] | select(.active) | .name')
        if [ -z "$missing" ]; then break; fi
        sleep 0.5
      done

      # No transition: this is a re-assert, not a rotation. On the outputs that
      # already show $img it is a no-op repaint rather than a visible fade.
      if awww img "$img" \
        --resize crop \
        --transition-type none; then
        echo "wallpaper-apply: re-asserted $img"
        # Seed/refresh the state file too, so the query-derived pick above only
        # ever has to happen once.
        mkdir -p "$state" && printf '%s\n' "$img" > "$current"
      else
        echo "wallpaper-apply: awww img failed for $img" >&2
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

in { inherit rotate apply fetch; }
