{ config, pkgs, lib, ... }:

{
  imports = [
    ./programs/delta.nix
    ./programs/gpg.nix

    ./programs/shell-tools.nix

  ];

  programs.home-manager.enable = true;
}
