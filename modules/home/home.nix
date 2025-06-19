{ config, pkgs, lib, inputs, ... }:

let 
  userPackages = import ../../home/packages.nix { inherit pkgs lib inputs; };
in
{
  options = {};

  config = {
    home = {
      packages = userPackages;
      stateVersion = "24.05";
      sessionVariables = {
        # SSH_AUTH_SOCK = "${config.xdg.dataHome}/ssh-agent";
        # BITWARDEN_SSH_AUTH_SOCK = "${config.home.sessionVariables.SSH_AUTH_SOCK}";
      };
    };
  };
}
