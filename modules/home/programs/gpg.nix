{ config, pkgs, lib, ... }:

{
  options = {};

  config = {
    programs.gpg.enable = true;
  };
}
