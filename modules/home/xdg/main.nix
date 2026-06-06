{ config, pkgs, lib, ... }:

let
  pgcliBase = builtins.readFile ../../../config/pgcli;
  # Per-environment variants of the shared pgcli config: each attribute is a
  # literal line in config/pgcli replaced with an environment-specific one.
  pgcliVariant = subs:
    builtins.replaceStrings (builtins.attrNames subs) (builtins.attrValues subs)
    pgcliBase;
in
{
  options = { };

  config = {
    xdg = {
      enable = true;
      configFile."pgcli/config".text = pgcliBase;
      configFile."pgcli/pgcli-prod".text = pgcliVariant {
        "history_file = default" =
          "history_file = ~/.config/pgcli/prod-history";
        # bold red host so production is unmistakable
        "prompt = '\\x1b[35m\\u@\\x1b[32m\\H:\\x1b[36m\\d>'" =
          "prompt = '\\x1b[35m\\u@\\x1b[1;31m\\H:\\x1b[36m\\d>'";
      };
      configFile."pgcli/pgcli-staging".text = pgcliVariant {
        "history_file = default" =
          "history_file = ~/.config/pgcli/staging-history";
      };
    };
  };
}
