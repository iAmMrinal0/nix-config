# Main package collection
{ pkgs ? import <nixpkgs> { } }:

{
  scripts = import ./scripts { inherit pkgs; };
  
  crow = pkgs.callPackage ./crow { };
  huenicorn = pkgs.callPackage ./huenicorn { inherit (pkgs) crow; };
  
}
