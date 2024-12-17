{ lib, pkgs, ... }:

let
  fingerprint = {
    eDP1 =
      "00ffffffffffff000e6f051400000000011e0104b51f117803e963ae5043b1270f53540000000101010101010101010101010101010140ce00a0f07028803020350035ae10000018000000fd00283c848435010a202020202020000000fe0043534f542054330a2020202020000000fe004d4e453030314541312d340a2001d802030f00e3058000e60605016a6a24000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009a";

  };
  laptopScreen = {
    enable = true;
    crtc = 1;
    mode = "2560x1440";
    position = "0x0";
    rate = "59.96";
    primary = false;
  };

in {
  programs.autorandr = {
    enable = true;
    hooks = {
      postswitch = {
        "change-background" =
          lib.readFile (pkgs.callPackage ./common/wallpaper.nix { });
      };
    };
    profiles = {
      "default" = {
        inherit fingerprint;
        config = {
          eDP1 = laptopScreen // {
            crtc = 0;
            primary = true;
          };
        };
      };
    };
  };
}
