{ lib, pkgs, ... }:

# Profiles for betazed (T480). Mirrors autorandr/betazed.nix profiles in kanshi
# format. Identifiers are derived from the autorandr EDIDs (Dell U2724DE). Verify on first sway boot via:
#   swaymsg -t get_outputs
# and adjust the `criteria` strings to match exactly.
let
  t480 = {
    status = "enable";
    mode = "1920x1080@60.02Hz";
    position = "0,0";
  };
  dellU2724DE = {
    status = "enable";
    mode = "2560x1440@120.00Hz";
    position = "0,0";
    # 27" 2K panel ≈ 109 DPI. Scale = 1.0 keeps native pixel mapping —
    # text is small but XWayland apps stay sharp. Try 1.1 if UI feels
    # cramped (also bump laptop x position below — see the math).
    scale = 1.0;
  };
  # Trailing glob: kanshi 1.8+ fnmatch()es criteria against
  # "make model serial" with no substring fallback.
  dellId = "Dell Inc. DELL U2724DE *";
  # Laptop's x in `home-right` is the Dell's logical width — i.e.
  # 2560 / dellU2724DE.scale, rounded to int. Computed inline so the
  # laptop butts right against the Dell's right edge with no overlap or
  # gap. Examples:
  #   scale 1.0  → 2560
  #   scale 1.1  → 2327   (2560 / 1.1 ≈ 2327.27)
  #   scale 1.25 → 2048
  # Overlap shows up as the Dell's right strip "spilling" onto the laptop;
  # gap shows up as the cursor getting stuck at the boundary.
  laptopXAfterDell =
    builtins.toString (2560 * 100 / (builtins.floor (dellU2724DE.scale * 100)));
in {
  profiles = {
    default = {
      outputs = [
        ({ criteria = "eDP-1"; } // t480)
      ];
    };
    home-right = {
      outputs = [
        ({ criteria = dellId; } // dellU2724DE // { position = "0,0"; })
        ({ criteria = "eDP-1"; } // t480 // { position = "${laptopXAfterDell},0"; })
      ];
    };
    # NOTE: home-left removed because both home-left and home-right matched
    # the same hardware criteria (same Dell + same eDP, only positions
    # differ), and kanshi alphabetically picked `home-left` first. If you
    # need the alternate layout, either rename this profile so it sorts
    # after `home-right`, or trigger it manually with a different
    # mechanism (e.g. a separate kanshi config invoked via a keybind).
  };
}
