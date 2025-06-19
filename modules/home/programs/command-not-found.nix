{ config, pkgs, lib, ... }:

{
  options = {};

  config = {
    programs.command-not-found.enable = true;
  };
}
