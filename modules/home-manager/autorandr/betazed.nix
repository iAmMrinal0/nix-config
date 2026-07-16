{ lib, pkgs, ... }:

let
  fingerprint = {
    eDP-1 =
      "00ffffffffffff0030e4210500000000001a0104951f1178ea9d35945c558f291e5054000000010101010101010101010101010101012e3680a070381f403020350035ae1000001a542b80a070381f403020350035ae1000001a000000fe004c4720446973706c61790a2020000000fe004c503134305746362d535042370074";
    DP-2 =
      "00ffffffffffff0010ace24255434a431c220104b53c22783962a5ad5046ab240e5054a54b00714f8180a940d1c081c0a9c001010101565e00a0a0a029503020350055502100001a000000ff00375339574733340a2020202020000000fc0044454c4c20553237323444450a000000fd003078b2b23c010a202020202020016e02031df14d3f40101f21222004131203110223097f0783010000e200eac8be00bea0a028503020a80455502100001ad97600a0a0a034503020350055502100001a866f80a0703840403020350055502100001a7e3900a080381f4030203a0055502100001a0000000000000000000000000000000000000000000000000000e4";
    DP-1 =
      "00ffffffffffff0010acdf4255434a431c220104b53c22783962a5ad5046ab240e5054a54b00714f8180a940d1c081c0a9c001010101565e00a0a0a029503020350055502100001a000000ff00375339574733340a2020202020000000fc0044454c4c20553237323444450a000000fd003078b2b23c010a202020202020017102031df14d3f40101f22212004131203110223097f0783010000e200eac8be00bea0a028503020a80455502100001ad97600a0a0a034503020350055502100001a866f80a0703840403020350055502100001a7e3900a080381f4030203a0055502100001a0000000000000000000000000000000000000000000000000000e4";
  };
  t480 = {
    enable = true;
    mode = "1920x1080";
    position = "0x0";
    rate = "60.02";
    primary = true;
  };
  dellU2724DE = {
    enable = false;
    mode = "2560x1440";
    position = "0x0";
    rate = "120.00";
    primary = true;
  };
in {
  profiles = {
    "default" = {
      inherit fingerprint;
      config = { eDP-1 = t480; };
    };
    "home-right" = {
      inherit fingerprint;
      config = {
        DP-2 = dellU2724DE // {
          enable = true;
          primary = true;
          position = "0x0";
        };
        eDP-1 = t480 // {
          position = "2560x0";
        };
      };
    };
    # Manual-only alternate: laptop on the LEFT, Dell to its right. Mirrors
    # kanshi's laptop-left (same name so the two backends stay in sync;
    # renamed from home-left, which also dropped the old 0x360 bottom-align
    # in favour of kanshi's top-align). Load it explicitly with
    # `autorandr --load laptop-left` (i.e. rofi-autorandr); home-right stays
    # the hotplug default. eDP-1 (1920 wide) sits at 0x0; Dell butts against
    # its right edge at x=1920.
    # Kept on DP-1 from the old home-left: the dock exposes the Dell on
    # DP-1 or DP-2 depending on enumeration (cf. the connector-name note in
    # kanshi/mordor.nix — kanshi globs by model so it doesn't care), and
    # DP-1 is the enumeration this arrangement was saved under. If the load
    # ever errors with DP-1 disconnected, swap it to DP-2.
    "laptop-left" = {
      inherit fingerprint;
      config = {
        eDP-1 = t480 // { position = "0x0"; };
        DP-1 = dellU2724DE // {
          enable = true;
          primary = true;
          position = "1920x0";
        };
      };
    };
  };
}
