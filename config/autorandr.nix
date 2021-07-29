{ wallpaper, ... }:

let
  fingerprint = {
    eDP-1 =
      "00ffffffffffff0030e4210500000000001a0104951f1178ea9d35945c558f291e5054000000010101010101010101010101010101012e3680a070381f403020350035ae1000001a542b80a070381f403020350035ae1000001a000000fe004c4720446973706c61790a2020000000fe004c503134305746362d535042370074";
    DP-1 =
      "00ffffffffffff001e6d805b2bca0000091e010380462778ea8cb5af4f43ab260e5054254b007140818081c0a9c0b300d1c08100d1cf5aa000a0a0a0465030383500b9882100001a000000fd0030781ee63c000a202020202020000000fc003237474c3835300a2020202020000000ff003030394e54464131483735350a019e020344f1230907074d100403011f13123f5d5e5f60616d030c001000b83c20006001020367d85dc401788003e30f0018681a00000101307800e305c000e6060501605928d97600a0a0a0345030203500b9882100001a565e00a0a0a0295030203500b9882100001a0000000000000000000000000000000000000000000000f4";
    HDMI-2 =
      "00ffffffffffff0010ace840574b4d42141c010380351e78eaee95a3544c99260f5054a54b00714f8180a940d1c00101010101010101023a801871382d40582c45000f282100001e000000ff003946384a46383546424d4b570a000000fc0044454c4c205532343137480a20000000fd00324b1e5311000a2020202020200127020326f14f90050403020716010611121513141f2309070765030c00100083010000e3050000023a801871382d40582c45000f282100001e011d8018711c1620582c25000f282100009e011d007251d01e206e2855000f282100001e8c0ad08a20e02d10103e96000f2821000018000000000000000000000000000000000019";
  };
  laptopScreen = {
    enable = true;
    crtc = 1;
    mode = "1920x1080";
    position = "0x0";
    rate = "60.02";
    primary = false;
  };

in {
  enable = true;
  hooks = { postswitch = { "change-background" = wallpaper; }; };
  profiles = {
    "default" = {
      inherit fingerprint;
      config = {
        eDP-1 = laptopScreen // {
          crtc = 0;
          primary = true;
        };
        DP-1.enable = false;
        HDMI-2.enable = false;
      };
    };
    "main_multi_below" = {
      inherit fingerprint;
      config = {
        HDMI-2 = {
          enable = true;
          crtc = 2;
          mode = "1920x1080";
          position = "0x0";
          rate = "60.00";
        };
        DP-1 = {
          enable = true;
          primary = true;
          crtc = 0;
          mode = "2560x1440";
          position = "1920x0";
          rate = "99.95";
        };
        eDP-1 = laptopScreen // { position = "0x1080"; };
      };
    };
    "multimonitor" = {
      inherit fingerprint;
      config = {
        HDMI-2 = {
          enable = true;
          crtc = 2;
          mode = "1920x1080";
          position = "0x0";
          rate = "60.00";
        };
        DP-1 = {
          enable = true;
          primary = true;
          crtc = 0;
          mode = "2560x1440";
          position = "1920x0";
          rate = "99.95";
        };
        eDP-1 = laptopScreen // { position = "1920x1440"; };
      };
    };
  };
}
