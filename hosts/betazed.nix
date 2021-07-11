# NixOS config for personal laptop
{ config, pkgs, ... }:

{
  imports =
    [
      ../hardware/betazed.nix
      ../base.nix
    ];

  networking.hostName = "betazed"; # Define your hostname.
}
