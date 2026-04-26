{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.emacs;
  emacsConfigPath = if cfg.useLocalConfig
    then cfg.localConfigPath
    else "${inputs.emacsConfiguration}/config.org";
  emacsWithPackagesFromUsePackage = pkgs.emacsWithPackagesFromUsePackage {
    config = emacsConfigPath;
    package = cfg.package;
    alwaysEnsure = true;
    alwaysTangle = true;
  };
in {
  options.modules.emacs = {
    enable = mkEnableOption "Enable Emacs configuration";

    package = mkOption {
      type = types.package;
      default = pkgs.emacs-unstable;
      description = "The Emacs package to use";
    };

    configureGitWithEmacs = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to configure Git to use Emacs";
    };

    i3Integration = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add Emacs keybinding to i3 config";
    };

    useLocalConfig = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If true, build Emacs against a local on-disk config path
        (see localConfigPath) instead of the pinned remote
        emacsConfiguration flake input. Useful while iterating on
        Emacs config changes before pushing them. Requires --impure
        evaluation because the path lives outside the flake.
      '';
    };

    localConfigPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.emacs.d/config.org";
      description = "Local Emacs config path used when useLocalConfig = true.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      emacsWithPackagesFromUsePackage
      pkgs.emacs-all-the-icons-fonts
    ];

    programs.git.extraConfig = mkIf cfg.configureGitWithEmacs {
      core.editor = "emacs";
      mergetool.ediff.cmd =
        "${emacsWithPackagesFromUsePackage}/bin/emacsclient -a '' --eval \"(ediff-merge-files-with-ancestor \\\"$LOCAL\\\" \\\"$REMOTE\\\" \\\"$BASE\\\" nil \\\"$MERGED\\\")\"";
    };

    # Add i3 keybinding and workspace assignment for Emacs if i3Integration is enabled
    xsession.windowManager.i3.config =
      let modifier = config.xsession.windowManager.i3.config.modifier;
      in mkIf cfg.i3Integration {
        keybindings = {
          "${modifier}+Control+e" =
            "exec ${emacsWithPackagesFromUsePackage}/bin/emacsclient -a '' -c";
        };

        # Add Emacs to code workspace (workspace 2)
        assigns."\"2  code\"" = [{ class = "Emacs"; }];
      };
  };
}
