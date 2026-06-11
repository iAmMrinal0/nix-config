{ lib, pkgs, ... }:

# Profiles for mordor (T14s). Mirrors autorandr/mordor.nix profiles in kanshi
# format. Identifiers are derived from the autorandr EDIDs (decoded
# make/model/serial from the fingerprint hex). Verify on first sway boot via:
#   swaymsg -t get_outputs
# and adjust the `criteria` strings to match exactly — in particular the
# Samsung make string ("Samsung Electric Company" is the hwdata pnp.ids
# expansion of SAM) and whatever connector names evdi outputs get under
# wlroots (the criteria match by description, so names shouldn't matter).
#
# DisplayLink note: the X11 side needed --match-edid because the dock's two
# Samsungs swap connector names across USB enumerations. Kanshi criteria
# match on "make model serial" descriptions instead of connector names, so
# the same profile covers both enumeration orders natively.
#
# Wayland has no "primary output" concept — the autorandr `primary` flags
# have no kanshi equivalent and are dropped.
let
  t14s = {
    status = "enable";
    mode = "2560x1440@59.96Hz";
    position = "0,0";
  };
  # Office dock (bzt-alt): two Samsungs over DisplayLink/evdi.
  ls27a600nId = "Samsung Electric Company LS27A600N H4ZT300907"; # centre
  ls27a600uId = "Samsung Electric Company LS27A600U H4ZT304864"; # left
  # Copenhagen office: Dell UP2716D over HDMI.
  dellUP2716DId = "Dell Inc. DELL UP2716D KRXTR76A947L";
  # Home: same Dell U2724DE (serial 7S9WG34) as betazed's home-right.
  dellU2724DEId = "Dell Inc. DELL U2724DE 7S9WG34";
in {
  profiles = {
    default = {
      outputs = [
        ({ criteria = "eDP-1"; } // t14s)
      ];
    };
    # Home: Dell left at 0,0, laptop butted against its right edge.
    home-right = {
      outputs = [
        {
          criteria = dellU2724DEId;
          status = "enable";
          mode = "2560x1440@120.00Hz";
          position = "0,0";
        }
        ({ criteria = "eDP-1"; } // t14s // { position = "2560,0"; })
      ];
    };
    # Office dock with the laptop under the centre monitor.
    bzt-alt = {
      outputs = [
        # LS27A600N: centre (was primary under X11)
        {
          criteria = ls27a600nId;
          status = "enable";
          mode = "2560x1440@75.00Hz";
          position = "2560,0";
        }
        # LS27A600U: left
        {
          criteria = ls27a600uId;
          status = "enable";
          mode = "2560x1440@74.97Hz";
          position = "0,0";
        }
        ({ criteria = "eDP-1"; } // t14s // { position = "2560,1440"; })
      ];
    };
    # Copenhagen office: single Dell UP2716D over HDMI, laptop stacked
    # directly below it.
    bzt-cph = {
      outputs = [
        {
          criteria = dellUP2716DId;
          status = "enable";
          mode = "2560x1440@59.95Hz";
          position = "0,0";
        }
        ({ criteria = "eDP-1"; } // t14s // { position = "0,1440"; })
      ];
    };
  };
}
