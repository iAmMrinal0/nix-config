# NixOS config for ThinkPad X1 Carbon
{ config, pkgs, ... }:

{
  imports =
    [ # Add hardware configuration for Carbon from machine later
      ../base.nix
    ];

  networking.hostName = "vormir"; # Define your hostname.
}
