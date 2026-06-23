{ lib, pkgs, ... }:

let
  edp = {
    status = "enable";
    mode = "2560x1600@60.001Hz";
    scale = 1.0;
    position = "0,0";
  };
  dellUP2716DId = "Dell Inc. DELL UP2716D"; # Copenhagen office
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
  };
}
