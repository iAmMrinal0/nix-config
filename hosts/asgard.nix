# NixOS config for desktop at Juspay
{ config, pkgs, ... }:

{
  imports =
    [
      ../hardware/desktop.nix
      ../base.nix
    ];

  networking.hostName = "asgard"; # Define your hostname.
}
