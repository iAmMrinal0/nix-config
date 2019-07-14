# NixOS config for ThinkPad X1 Carbon
{ config, pkgs, ... }:

{
  imports =
    [ ../hardware/carbon.nix
      ../base.nix
    ];

  networking.hostName = "vormir"; # Define your hostname.
}
