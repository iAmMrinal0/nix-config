{ config, pkgs, lib, ... }:

{
  options = {};

  config = {
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
