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
        default = [ "broot" "nix-index" "jq" ];
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
        # Sets daemon.enabled + daemon.systemd_socket in config.toml and
        # creates the atuin-daemon.{service,socket} systemd user units.
        daemon.enable = true;
        # All available settings (with docs) for the pinned atuin version:
        # https://github.com/atuinsh/atuin/blob/v18.15.2/crates/atuin-client/config.toml
        settings = {
          # E2E sync key comes from sops (see base.nix secrets); a fresh
          # machine only needs `atuin login` + `atuin sync` to restore the
          # full shell history.
          key_path = "/run/secrets/atuin-key";
          # Settings carried over from the pre-home-manager config.toml
          # (now config.toml.bak): defining any `settings` makes
          # home-manager own the whole file, so everything non-default
          # must be declared here.
          enter_accept = true;
          # No filter_mode set: the default is the first applicable entry in
          # search.filters, so inside a git repo it's "workspace" (whole-repo
          # history, needs workspaces = true below) and "host" elsewhere.
          search.filters = [
            "workspace"
            "host"
            "session"
            "directory"
            "global"
          ];
          filter_mode_shell_up_key_binding = "directory";
          show_preview = true;
          sync.records = true;
          # Filter history to the whole git repo, not just the exact cwd,
          # when using the directory/workspace filter.
          workspaces = true;
          # Open interactive search in a tmux popup (tmux >= 3.2).
          tmux.enabled = true;
        };
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
      nix-index = mkIf (cfg.simpleTools.enable
        && elem "nix-index" cfg.simpleTools.enabledTools) {
          enable = true;
          enableZshIntegration = true;
        };
      nix-index-database.comma.enable = mkIf (cfg.simpleTools.enable
        && elem "nix-index" cfg.simpleTools.enabledTools) true;
      jq.enable =
        mkIf (cfg.simpleTools.enable && elem "jq" cfg.simpleTools.enabledTools)
        true;
    };
  };
}
