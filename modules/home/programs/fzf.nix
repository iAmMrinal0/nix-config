{ config, pkgs, lib, ... }:

{
  options = {};

  config = {
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
