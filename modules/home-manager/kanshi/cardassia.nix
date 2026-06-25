{ lib, pkgs, ... }:

let
  edp = {
    status = "enable";
    mode = "2560x1600@90.001Hz";
    scale = 1.0;
    position = "0,0";
  };
  dellUP2716DId = "Dell Inc. DELL UP2716D"; # Copenhagen office
  dellU2724DEId = "Dell Inc. DELL U2724DE"; # home (same panel as mordor's)
in {
  profiles = {
    default = {
      outputs = [
        ({ criteria = "eDP-1"; } // edp)
      ];
    };
    bzt-cph = {
      outputs = [
        {
          criteria = dellUP2716DId;
          status = "enable";
          mode = "2560x1440@59.951Hz";
          position = "0,0";
        }
        ({ criteria = "eDP-1"; } // edp // { position = "0,1440"; })
      ];
    };
    # Home: Dell U2724DE on top at its max 120 Hz, laptop stacked directly below
    # it. eDP runs 90 Hz (its only modes are 60/90). Matches the current layout.
    home = {
      outputs = [
        {
          criteria = dellU2724DEId;
          status = "enable";
          mode = "2560x1440@120.000Hz";
          position = "0,0";
        }
        ({ criteria = "eDP-1"; } // edp // { position = "0,1440"; })
      ];
    };
  };
}
