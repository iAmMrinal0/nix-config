{ config, pkgs, lib, ... }:

with lib;

let cfg = config.personal.shell-tools;
in {
  options.personal.shell-tools = {
    enable = mkEnableOption "Shell tools configuration";

    atuin = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable atuin shell history";
      };

      enableZshIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable Zsh integration for atuin";
      };
    };

    direnv = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable direnv";
      };

      enableZshIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable Zsh integration for direnv";
      };

      nix-direnv = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description =
            "Whether to enable nix-direnv for better performance with Nix";
        };
      };
    };

    fzf = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable fzf for fuzzy finding";
      };

      enableZshIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable Zsh integration for fzf";
      };
    };

    simpleTools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description =
          "Whether to enable simple shell tools with minimal configuration";
      };

      enabledTools = mkOption {
        type = with types; listOf str;
        default = [ "broot" "command-not-found" "jq" ];
        description = "List of simple tools to enable";
        example = ''[ "broot" "jq" ]'';
      };
    };
  };

  config = mkIf cfg.enable {
    programs = {
      atuin = mkIf cfg.atuin.enable {
        enable = true;
        enableZshIntegration = cfg.atuin.enableZshIntegration;
      };

      direnv = mkIf cfg.direnv.enable {
        enable = true;
        enableZshIntegration = cfg.direnv.enableZshIntegration;
        nix-direnv.enable = cfg.direnv.nix-direnv.enable;
      };

      fzf = mkIf cfg.fzf.enable {
        enable = true;
        enableZshIntegration = cfg.fzf.enableZshIntegration;
      };

      broot.enable = mkIf
        (cfg.simpleTools.enable && elem "broot" cfg.simpleTools.enabledTools)
        true;
      command-not-found.enable = mkIf (cfg.simpleTools.enable
        && elem "command-not-found" cfg.simpleTools.enabledTools) true;
      jq.enable =
        mkIf (cfg.simpleTools.enable && elem "jq" cfg.simpleTools.enabledTools)
        true;
    };
  };
}
