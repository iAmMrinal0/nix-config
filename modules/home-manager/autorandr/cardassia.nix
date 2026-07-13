{ lib, pkgs, ... }:

# Mirrors kanshi/cardassia.nix profiles for X11/i3 fallback sessions. autorandr
# runs with services.autorandr.matchEdid = true, so the output-name keys below
# are just labels: profiles are matched (and outputs bound) by EDID content, not
# by the X11 connector name. The Dell externals are the same physical units as
# mordor (matching serials), so their EDIDs are byte-identical and reused from
# autorandr/mordor.nix; eDP-1 was read from this laptop's panel.
let
  fingerprint = {
    eDP-1 =
      "00ffffffffffff000e774914*";
    HDMI-1 = # DELL P2720D  — Copenhagen office, current desk
      "00ffffffffffff0010ac01d1*";
    HDMI-2 = # DELL UP2716D — Copenhagen office, old desk
      "00ffffffffffff0010acde40*";
    DP-1 = # SAMSUNG S34C65xV — Copenhagen office (curved ultrawide)
      "00ffffffffffff004c2df973*";
    DVI-I-1-1 = # SAMSUNG LS27A600N — office DisplayLink dock (bzt-alt), centre
      "00ffffffffffff004c2d6e71*";
    DVI-I-2-2 = # SAMSUNG LS27A600U — office DisplayLink dock (bzt-alt), left
      "00ffffffffffff004c2d7271*";
    DP-3 = # DELL U2724DE  — home (same panel as mordor's)
      "00ffffffffffff0010ace242*";
  };
  # eDP: 2560x1600 @ 90 Hz, mirroring kanshi (panel exposes only 60/90 Hz). If an
  # X11 session can't find the 90 Hz mode, drop rate to "60.00".
  edp = {
    enable = true;
    mode = "2560x1600";
    position = "0x0";
    rate = "90.00";
    primary = false;
  };
in {
  profiles = {
    "default" = {
      inherit fingerprint;
      config = {
        eDP-1 = edp // { primary = true; };
      };
    };
    # Copenhagen office (current desk): Dell P2720D primary on top, laptop below.
    "bzt-cph" = {
      inherit fingerprint;
      config = {
        HDMI-1 = {
          enable = true;
          primary = true;
          mode = "2560x1440";
          position = "0x0";
          rate = "59.95";
        };
        eDP-1 = edp // { position = "0x1440"; };
      };
    };
    # Copenhagen office (curved ultrawide): Samsung S34C65xV primary on top at
    # 100 Hz, laptop centered below (ultrawide is 880 px wider).
    "bzt-cph-curved" = {
      inherit fingerprint;
      config = {
        DP-1 = {
          enable = true;
          primary = true;
          mode = "3440x1440";
          position = "0x0";
          rate = "99.98";
        };
        eDP-1 = edp // { position = "440x1440"; };
      };
    };
    # Office DisplayLink dock (bzt-alt): two Samsungs, laptop under the centre
    # monitor. Geometry mirrors autorandr/mordor.nix bzt-alt; the DVI-I-* keys
    # are just labels (matchEdid), so either USB enumeration order works.
    "bzt-alt" = {
      inherit fingerprint;
      config = {
        # LS27A600N: centre, primary
        DVI-I-1-1 = {
          enable = true;
          primary = true;
          mode = "2560x1440";
          position = "2560x0";
          rate = "75.00";
        };
        # LS27A600U: left
        DVI-I-2-2 = {
          enable = true;
          primary = false;
          mode = "2560x1440";
          position = "0x0";
          rate = "74.97";
        };
        eDP-1 = edp // { position = "2560x1440"; };
      };
    };
    # Copenhagen office (old desk): Dell UP2716D primary on top, laptop below.
    "bzt-cph-bkp" = {
      inherit fingerprint;
      config = {
        HDMI-2 = {
          enable = true;
          primary = true;
          mode = "2560x1440";
          position = "0x0";
          rate = "59.95";
        };
        eDP-1 = edp // { position = "0x1440"; };
      };
    };
    # Home: Dell U2724DE primary on the left at 120 Hz, laptop on the right,
    # bottom edges aligned.
    "home" = {
      inherit fingerprint;
      config = {
        DP-3 = {
          enable = true;
          primary = true;
          mode = "2560x1440";
          position = "0x160";
          rate = "120.00";
        };
        eDP-1 = edp // { position = "2560x0"; };
      };
    };
  };
}
