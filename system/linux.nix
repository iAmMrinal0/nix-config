{ lib, pkgs, ... }:

let


  packages = [

  ];

in {
  home = {
    inherit packages;
    sessionVariables = { };
  };
}
