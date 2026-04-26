{ config, lib, pkgs, inputs, ... }:

with lib;

let cfg = config.modules.gc;
in {
  options.modules.gc = {
    enable = mkEnableOption "Enable garbage collection configuration";

    method = mkOption {
      type = types.enum [ "nix" "nh" ];
      default = "nix";
      description = "The method to use for garbage collection";
    };

    pinLastSuccessfulBoot = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Create a persistent GC root at
        /nix/var/nix/gcroots/last-successful-system pointing at the
        currently booted system, refreshed on every successful boot.
        Survives nix-env --delete-generations and nix-collect-garbage -d.
      '';
    };

    nix = {
      gc = mkOption {
        type = types.submodule {
          options = {
            automatic = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to automatically run garbage collection";
            };
            dates = mkOption {
              type = types.listOf types.str;
              default = [ "weekly" ];
              description = "The dates on which to run garbage collection";
            };
            randomizedDelaySec = mkOption {
              type = types.str;
              default = "14m";
              description = "Randomized delay for garbage collection";
            };
            options = mkOption {
              type = types.str;
              default = "--delete-older-than 10d";
              description = "Additional options for garbage collection";
            };
          };
          description = "Nix garbage collection settings";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    nix.gc = mkIf (cfg.method == "nix") {
      automatic = true;
      dates = [ "daily" ];
      randomizedDelaySec = "14m";
      options = "--delete-older-than 10d";
    };

    programs.nh = mkIf (cfg.method == "nh") {
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
    };

    systemd.services.pin-last-successful-system = mkIf cfg.pinLastSuccessfulBoot {
      description = "Pin the last successfully-booted NixOS system as a GC root";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${config.nix.package}/bin/nix-store --add-root /nix/var/nix/gcroots/last-successful-system -r /run/booted-system >/dev/null
      '';
    };
  };
}
