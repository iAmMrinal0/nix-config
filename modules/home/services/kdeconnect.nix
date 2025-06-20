{ config, pkgs, lib, ... }:

{
  options = { };

  config = {
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
