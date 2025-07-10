# Main package collection
{ pkgs ? import <nixpkgs> { } }:

{
  scripts = import ./scripts { inherit pkgs; };

}
