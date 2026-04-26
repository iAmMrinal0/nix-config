{ config, lib, ... }:

with lib;

let cfg = config.personal.workspaces;
in {
  options.personal.workspaces = {
    items = mkOption {
      type = types.listOf (types.submodule {
        options = {
          key = mkOption {
            type = types.str;
            description = "Stable identifier for cross-module reference (e.g. 'code').";
          };
          label = mkOption {
            type = types.str;
            description = "Display string after the workspace number, e.g. '\uf121 code'.";
          };
        };
      });
      default = [
        { key = "term"; label = " term"; }
        { key = "code"; label = " code"; }
        { key = "web"; label = " web"; }
        { key = "music"; label = "♪ music"; }
        { key = "avoid"; label = " avoid"; }
        { key = "scratch1"; label = "scratch"; }
        { key = "scratch2"; label = "scratch"; }
        { key = "scratch3"; label = "scratch"; }
        { key = "bg"; label = " bg"; }
      ];
      description = "Ordered workspaces. Position determines the numeric prefix.";
    };

    separator = mkOption {
      type = types.str;
      default = " ·";
      description = "Suffix appended to each workspace name in the bar.";
    };

    numbered = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Computed full names, ordered.";
      default = let
        numbers = imap1 (i: _: toString i) cfg.items;
      in zipListsWith (n: w: "${n} ${w.label}${cfg.separator}") numbers cfg.items;
    };

    byKey = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      description = "Map of stable key to the full workspace name.";
      default = let
        full = cfg.numbered;
      in listToAttrs (imap0 (i: w: nameValuePair w.key (elemAt full i)) cfg.items);
    };
  };
}
