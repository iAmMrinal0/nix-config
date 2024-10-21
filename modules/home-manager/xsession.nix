{ lib, pkgs, ... }:

let wallpaper = lib.readFile (pkgs.callPackage ./common/wallpaper.nix { });
in {
  imports = [ ./i3 ];
  xsession = {
    enable = true;
    initExtra = wallpaper;
  };
}
