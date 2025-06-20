{ config, pkgs, lib, ... }:

{
  options = { };

  config = {
    xdg = {
      enable = true;
      configFile."pgcli/config".text = builtins.readFile ../../../config/pgcli;
    };
  };
}
