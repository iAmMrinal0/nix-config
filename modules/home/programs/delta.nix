{ config, pkgs, lib, ... }:

{
  options = { };

  config = {
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
