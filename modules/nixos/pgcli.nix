{ config, username, ... }:

let
  # Benign pgcli settings live in the repo; the [alias_dsn] sections (work DB
  # hosts/users) live in sops and are appended at render time, so they never
  # enter the nix store or the public repo. Rendered files land under
  # /run/secrets/rendered/, readable only by ${username}; the home-manager
  # side (modules/home/xdg/main.nix) symlinks ~/.config/pgcli/* at them.
  pgcliBase = builtins.readFile ../../config/pgcli;
  # Per-environment variants of the shared pgcli config: each attribute is a
  # literal line in config/pgcli replaced with an environment-specific one.
  pgcliVariant = subs:
    builtins.replaceStrings (builtins.attrNames subs) (builtins.attrValues subs)
    pgcliBase;
  mkPgcliTemplate = text: {
    content = text + "\n" + config.sops.placeholder."pgcli-alias-dsn";
    owner = username;
  };
in {
  sops.secrets."pgcli-alias-dsn" = { };

  sops.templates."pgcli-config" = mkPgcliTemplate pgcliBase;
  sops.templates."pgcli-prod" = mkPgcliTemplate (pgcliVariant {
    "history_file = default" = "history_file = ~/.config/pgcli/prod-history";
    # bold red host so production is unmistakable
    "prompt = '\\x1b[35m\\u@\\x1b[32m\\H:\\x1b[36m\\d>'" =
      "prompt = '\\x1b[35m\\u@\\x1b[1;31m\\H:\\x1b[36m\\d>'";
  });
  sops.templates."pgcli-staging" = mkPgcliTemplate (pgcliVariant {
    "history_file = default" = "history_file = ~/.config/pgcli/staging-history";
  });
}
