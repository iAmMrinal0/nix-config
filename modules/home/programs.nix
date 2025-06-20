{ config, pkgs, lib, ... }:

{
  imports = [
    ./programs/gpg.nix

    ./programs/shell-tools.nix

  ];

  programs.home-manager.enable = true;
}
