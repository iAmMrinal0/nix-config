{ config, pkgs, lib, ... }:

{
  imports = [ ./kdeconnect.nix ./playerctld.nix ./udiskie.nix ];

  config = { };
}
