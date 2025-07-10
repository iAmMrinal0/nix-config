{ config, pkgs, lib, ... }:

{
  options = { };

  config = {
    xdg = {
      enable = true;
      configFile."pgcli/config".text = builtins.readFile ../../../config/pgcli;
      configFile."pgcli/pgcli-prod".text =
        builtins.readFile ../../../config/pgcli-prod;
      configFile."pgcli/pgcli-staging".text =
        builtins.readFile ../../../config/pgcli-staging;
    };
  };
}
