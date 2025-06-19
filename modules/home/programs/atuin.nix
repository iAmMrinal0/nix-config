{ config, pkgs, lib, ... }:

{
  options = {};

  config = {
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
