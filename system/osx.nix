{ pkgs, ... }:

let
  emacsConfig = import ../config/emacs.nix { inherit pkgs; };
  packages = [
    pkgs.iosevka
    pkgs.lorri
    (pkgs.emacsWithPackagesFromUsePackage emacsConfig)
  ];
  programs = { };
  nixpkgs = {
    config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        nur = import (builtins.fetchTarball
          "https://github.com/nix-community/NUR/archive/master.tar.gz") {
            inherit pkgs;
          };
      };
    };

    overlays = [
      (import (builtins.fetchTarball {
        url =
          "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz";
      }))
      (import ../overlays.nix)
    ];
  };
in {
  inherit nixpkgs programs;
  home = {
    inherit packages;
    sessionVariables = { EDITOR = "vim"; };
  };
}
