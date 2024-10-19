{ lib, pkgs, ... }:

let wallpaper = lib.readFile (pkgs.callPackage ../scripts/wallpaper.nix { });
in {
  imports = [ ./i3config.nix ];
  xsession = {
    enable = true;
    initExtra = wallpaper;
  };
}
