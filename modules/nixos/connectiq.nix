{ config, lib, pkgs, username, ... }:

with lib;

# Garmin Connect IQ toolchain enablement.
#
# Install method: direct SDK download, NOT via the SDK Manager.
# - Garmin's official Linux SDK Manager tarball links against
#   libwebkit2gtk-4.0, removed from modern nixpkgs.
# - The community pcolby/connectiq-sdk-manager AppImage is upstream-
#   broken on modern distros: its bundled webkit lib hardcodes the
#   Debian multiarch path /usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/
#   for helper processes, WEBKIT_EXEC_PATH is ignored by this build,
#   and even after shimming that path the OAuth login WebView renders
#   blank (see pcolby/connectiq-sdk-manager#3, unresolved as of
#   2025-11; multiple Ubuntu 24.04+ users hit the same symptom).
#
# Instead, fetch the SDK directly from Garmin's public manifest:
#   https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json
# No auth required for the SDK zip itself. Device profiles, however,
# ARE auth-gated (api.gcs.garmin.com/ciq-product-onboarding/devices)
# — they get downloaded one-time via the `garmin-sdk-manager` script
# (rootless podman + Ubuntu 22.04, see pkgs/scripts/garmin-sdk-
# container/) into ~/.Garmin/ConnectIQ/Devices/. After that the
# container image can be removed; device profiles persist on the
# host.
#
# This module provides everything needed for a fresh machine:
#   - jdk17 — monkeyc/monkeydo are Java tools; SDK requires JDK 17
#   - SDK zip + extract via home-manager activation → ~/.Garmin/
#     ConnectIQ/Sdks/<sdk-name>/ and current-sdk.cfg pointer
#   - `garmin-sdk-manager` script in PATH for the one-time device
#     profile download (also handy for SDK Manager re-runs later)
#   - podman runtime for the container
#   - /bin/bash symlink — vendor scripts use #!/bin/bash shebangs
#   - Garmin USB udev rule (vendor 091e) so sideload over USB works
#     without manual permission tweaking
#   - appimage-run + binfmt — kept enabled for general AppImage use
#     on the host; not strictly required for the SDK itself
#
# What the user still does by hand on a fresh machine:
#   1. nixos-rebuild switch (installs all the above + SDK)
#   2. garmin-sdk-manager → log in once, download device profiles
#   3. Generate a developer signing key (openssl) — must remain a
#      secret, not in Nix unless sops-encrypted
#   4. Install VS Code's garmin.monkey-c extension (declaratively in
#      modules/nixos/vscode.nix, picked up on the next rebuild)

let
  cfg = config.modules.connectiq;

  # Pin the SDK we want declaratively. Bump these three together when
  # a new release is desired; nixos-rebuild will fail with the actual
  # hash the first time, paste it into `sdkSha256` and rebuild again.
  # Filenames come from:
  #   curl https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json
  sdkBaseName = "connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b";
  sdkSha256 = "sha256-lvoqMpRjepDDloYWpvMCJRGHr9Gj0+IN+b/4oGsTiSA=";

  sdkZip = pkgs.fetchurl {
    url = "https://developer.garmin.com/downloads/connect-iq/sdks/${sdkBaseName}.zip";
    sha256 = sdkSha256;
  };
in {
  options.modules.connectiq = {
    enable = mkEnableOption
      "Enable Garmin Connect IQ toolchain (SDK + jdk17 + podman SDK Manager + udev rule)";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jdk17
    ];

    # `enable` installs appimage-run; `binfmt` registers it so AppImages
    # run directly without the `appimage-run` prefix. Both are needed —
    # `binfmt = true` alone is a no-op (the NixOS module gates the whole
    # config block on `enable`).
    programs.appimage = {
      enable = true;
      binfmt = true;
    };

    # Rootless podman for the one-time SDK Manager container that
    # downloads device profiles into ~/.Garmin/ConnectIQ/Devices/.
    # The container itself lives outside Nix (built on first run of
    # `garmin-sdk-manager`); only the runtime is declared here.
    virtualisation.podman = {
      enable = true;
      dockerCompat = false;
    };

    # Garmin's SDK ships shell scripts (monkeyc, monkeydo, etc.) with
    # #!/bin/bash shebangs. Rather than patch them on every SDK
    # re-download, expose /bin/bash system-wide via tmpfiles. Targeted
    # FHS concession — no broader /usr/lib pollution.
    systemd.tmpfiles.rules = [
      "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
    ];

    # Garmin USB vendor ID 091e. uaccess hands the device to the
    # logged-in seat without needing a static group membership.
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="091e", MODE="0666", TAG+="uaccess"
    '';

    # Function form so we get home-manager's own `lib` (which has
    # `lib.hm.dag.entryAfter`) instead of the bare NixOS lib.
    home-manager.users.${username} = { lib, ... }: {
      # `garmin-sdk-manager` on PATH — wraps the rootless podman +
      # Ubuntu 22.04 image for the SDK Manager GUI. First invocation
      # builds the image (~5 min); subsequent runs reuse the cached
      # image.
      home.packages = [ pkgs.my.scripts.garmin-sdk-manager ];

      # Extract the pinned SDK into ~/.Garmin/ConnectIQ/Sdks/ on
      # activation. Idempotent — only extracts if the target dir is
      # missing. current-sdk.cfg is always rewritten so the active
      # SDK matches what's pinned in Nix.
      home.activation.installGarminSdk =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          SDK_DIR="$HOME/.Garmin/ConnectIQ/Sdks/${sdkBaseName}"
          if [ ! -d "$SDK_DIR" ]; then
            echo "Installing Garmin Connect IQ SDK ${sdkBaseName}..." >&2
            $DRY_RUN_CMD mkdir -p "$SDK_DIR"
            $DRY_RUN_CMD ${pkgs.unzip}/bin/unzip -q ${sdkZip} -d "$SDK_DIR"
          fi
          $DRY_RUN_CMD sh -c "echo '$SDK_DIR' > '$HOME/.Garmin/ConnectIQ/current-sdk.cfg'"
        '';
    };
  };
}
