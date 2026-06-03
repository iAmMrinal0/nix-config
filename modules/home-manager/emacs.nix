{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.emacs;
  # Normal mode: the env prebuilt by the emacsConfiguration flake against
  # its own lock (substitutes from iammrinal0.cachix.org). Local mode:
  # build from the on-disk config as before, for iterating pre-push.
  emacsEnv = if cfg.useLocalConfig
    then pkgs.emacsWithPackagesFromUsePackage {
      config = cfg.localConfigPath;
      package = cfg.package;
      alwaysEnsure = true;
      alwaysTangle = true;
    }
    else inputs.emacsConfiguration.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  options.modules.emacs = {
    enable = mkEnableOption "Enable Emacs configuration";

    package = mkOption {
      type = types.package;
      default = pkgs.emacs-unstable;
      description = ''
        The Emacs package to use. Only applies when useLocalConfig = true;
        in normal mode the variant is chosen by the emacsConfiguration
        flake (so the prebuilt cached env is used as-is).
      '';
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

    swayIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add Emacs keybinding and assign to sway config";
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
      emacsEnv
      pkgs.emacs-all-the-icons-fonts
    ];

    programs.git.extraConfig = mkIf cfg.configureGitWithEmacs {
      core.editor = "emacs";
      mergetool.ediff.cmd =
        "${emacsEnv}/bin/emacsclient -a '' --eval \"(ediff-merge-files-with-ancestor \\\"$LOCAL\\\" \\\"$REMOTE\\\" \\\"$BASE\\\" nil \\\"$MERGED\\\")\"";
    };

    # Add i3 keybinding and workspace assignment for Emacs if i3Integration is enabled
    xsession.windowManager.i3.config =
      let
        modifier = config.xsession.windowManager.i3.config.modifier;
        codeWorkspace = config.personal.workspaces.byKey.code;
      in mkIf cfg.i3Integration {
        keybindings = {
          "${modifier}+Control+e" =
            "exec ${emacsEnv}/bin/emacsclient -a '' -c";
        };

        # Assign Emacs windows to the 'code' workspace
        assigns."\"${codeWorkspace}\"" = [{ class = "Emacs"; }];
      };

    # Mirror the i3 integration for sway. Emacs typically runs via XWayland
    # so `class = "Emacs"` still matches; if you switch to native-Wayland
    # Emacs (PGTK), the criterion would need to become `app_id`.
    wayland.windowManager.sway.config =
      let
        modifier = config.wayland.windowManager.sway.config.modifier;
        codeWorkspace = config.personal.workspaces.byKey.code;
      in mkIf cfg.swayIntegration {
        keybindings = {
          "${modifier}+Control+e" =
            "exec ${emacsWithPackagesFromUsePackage}/bin/emacsclient -a '' -c";
        };

        assigns."\"${codeWorkspace}\"" = [{ class = "Emacs"; }];
      };
  };
}
