{ lib, pkgs, ... }:

let
  edp = {
    status = "enable";
    mode = "2560x1600@90.001Hz";
    scale = 1.0;
    position = "0,0";
  };
  dellP2720DId = "Dell Inc. DELL P2720D"; # Copenhagen office (current desk)
  dellUP2716DId = "Dell Inc. DELL UP2716D"; # Copenhagen office (old desk)
  dellU2724DEId = "Dell Inc. DELL U2724DE"; # home (same panel as mordor's)
  samsungS34C65VId = "Samsung Electric Company S34C65xV"; # Copenhagen office (curved ultrawide)
  # Office DisplayLink dock (bzt-alt), same physical units as mordor's.
  ls27a600nId = "Samsung Electric Company LS27A600N"; # centre
  ls27a600uId = "Samsung Electric Company LS27A600U"; # left
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
          criteria = dellP2720DId;
          status = "enable";
          mode = "2560x1440@59.951Hz";
          position = "0,0";
        }
        ({ criteria = "eDP-1"; } // edp // { position = "0,1440"; })
      ];
    };
    # Copenhagen office (curved ultrawide): Samsung S34C65xV on top at its max
    # 3440x1440@100 Hz, laptop centered below (ultrawide is 880 px wider).
    bzt-cph-curved = {
      outputs = [
        {
          criteria = samsungS34C65VId;
          status = "enable";
          mode = "3440x1440@99.981Hz";
          position = "0,0";
        }
        ({ criteria = "eDP-1"; } // edp // { position = "440,1440"; })
      ];
    };
    # Office dock (bzt-alt): two Samsungs over DisplayLink/evdi, laptop under
    # the centre monitor. Geometry mirrors kanshi/mordor.nix bzt-alt.
    bzt-alt = {
      outputs = [
        # LS27A600N: centre
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
        ({ criteria = "eDP-1"; } // edp // { position = "2560,1440"; })
      ];
    };
    bzt-cph-bkp = {
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
    # Home: Dell U2724DE (over USB-C) on the left at its max 120 Hz, laptop on
    # the right. Bottom edges aligned: eDP is 1600 tall vs the Dell's 1440.
    # eDP runs 90 Hz (its only modes are 60/90).
    home = {
      outputs = [
        {
          criteria = dellU2724DEId;
          status = "enable";
          mode = "2560x1440@120.000Hz";
          position = "0,160";
        }
        ({ criteria = "eDP-1"; } // edp // { position = "2560,0"; })
      ];
    };
  };
}
