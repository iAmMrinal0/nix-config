{ lib, pkgs, ... }:

let wallpaper = lib.readFile (pkgs.callPackage ../../scripts/wallpaper.nix { });
in {
  imports = [ ./i3 ];
  xsession = {
    enable = true;
    initExtra = wallpaper;
  };
}
