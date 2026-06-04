{ writeShellApplication, podman, xhost, coreutils }:

# Wrap the one-time Ubuntu-22.04 podman container that runs Garmin's
# official SDK Manager (the only working path to download device
# profiles, since the OAuth WebView is broken on modern hosts and
# Garmin's device API requires login). On first invocation this
# builds the image (~5 min, downloads ubuntu:22.04 + apt deps + the
# SDK Manager tarball). Subsequent runs reuse the cached image. The
# login token persists across runs because $HOME/.Garmin is bind-
# mounted. Once epix2 / epix2pro profiles are downloaded into
# $HOME/.Garmin/ConnectIQ/Devices/, this script is no longer needed
# — but keeping it around makes future device updates a one-command
# operation.

writeShellApplication {
  name = "garmin-sdk-manager";
  runtimeInputs = [ podman xhost coreutils ];
  text = ''
    IMAGE=garmin-sdk:22.04
    CONTAINERFILE=${./Containerfile}

    if ! podman image exists "$IMAGE"; then
      echo "Building $IMAGE (one-time, ~5 min)..." >&2
      tmp=$(mktemp -d)
      cp "$CONTAINERFILE" "$tmp/Containerfile"
      podman build -t "$IMAGE" -f "$tmp/Containerfile" "$tmp"
      rm -rf "$tmp"
    fi

    mkdir -p "$HOME/.Garmin/ConnectIQ"

    # Belt-and-suspenders for the X11 cookie auth — keep-id maps the
    # container UID to the host user, so XAUTHORITY mount is usually
    # enough, but xhost handles the edge case where it isn't.
    xhost +SI:localuser:"$USER" >/dev/null 2>&1 || true
    cleanup() { xhost -SI:localuser:"$USER" >/dev/null 2>&1 || true; }
    trap cleanup EXIT

    podman run --rm -it \
      --userns=keep-id \
      --network=host \
      -e DISPLAY="$DISPLAY" \
      -e XAUTHORITY="''${XAUTHORITY:-$HOME/.Xauthority}" \
      -e HOME="$HOME" \
      -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
      -v "''${XAUTHORITY:-$HOME/.Xauthority}:''${XAUTHORITY:-$HOME/.Xauthority}:ro" \
      -v "$HOME/.Garmin:$HOME/.Garmin:rw" \
      -w "$HOME/.Garmin" \
      "$IMAGE"
  '';
}
