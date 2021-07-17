{ config, pkgs, lib, ... }:

let
  # brotab = callPackage ./pkgs/brotab { };

  common = import ./system/common.nix { inherit lib pkgs; };

in {

  programs = common.programs;

  home.packages = common.home.packages;

  home.sessionVariables = common.home.sessionVariables;

} // common.extras
