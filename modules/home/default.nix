{ config, pkgs, lib, options, ... }:

{
  options = { };

  imports = [ ./xdg.nix ./services.nix ./programs.nix ./home.nix ];

  config = { };
}
