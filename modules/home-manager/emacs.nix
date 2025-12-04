{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.emacs;
  emacsWithPackagesFromUsePackage = (pkgs.emacsWithPackagesFromUsePackage {
    config = "${inputs.emacsConfiguration}/init.el";
    defaultInitFile = true;
    package = cfg.package;
    extraEmacsPackages = epkgs:
      (with epkgs; [
        ace-window
        ag
        all-the-icons
        anzu
        avy
        company
        bind-key
        dhall-mode
        diminish
        direnv
        dockerfile-mode
        editorconfig
        exec-path-from-shell
        expand-region
        flycheck
        free-keys
        git-gutter
        good-scroll
        groovy-mode
        gruvbox-theme
        haskell-mode
        helm
        # helm-ag
        helm-projectile
        hungry-delete
        hydra
        keychain-environment
        keyfreq
        lsp-haskell
        lsp-mode
        lsp-ui
        magit
        markdown-mode
        multiple-cursors
        nix-buffer
        nix-mode
        org-bullets
        pdf-tools
        projectile
        psc-ide
        purescript-mode
        rainbow-delimiters
        rainbow-mode
        smart-mode-line
        smartparens
        use-package
        web-mode
        which-key
        yaml-mode
        yasnippet
        zerodark-theme
        zop-to-char
      ]);
  });
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
  };

  config = mkIf cfg.enable {
    home.packages = [ emacsWithPackagesFromUsePackage ];

    programs.git.extraConfig = mkIf cfg.configureGitWithEmacs {
      core.editor = "emacs";
      mergetool.ediff.cmd =
        "${pkgs.emacs}/bin/emacsclient -a '' --eval \"(ediff-merge-files-with-ancestor \\\"$LOCAL\\\" \\\"$REMOTE\\\" \\\"$BASE\\\" nil \\\"$MERGED\\\")\"";
    };

    # Add i3 keybinding and workspace assignment for Emacs if i3Integration is enabled
    xsession.windowManager.i3.config =
      let modifier = config.xsession.windowManager.i3.config.modifier;
      in mkIf cfg.i3Integration {
        keybindings = {
          "${modifier}+Control+e" =
            "exec ${cfg.package}/bin/emacsclient -a '' -c";
        };

        # Add Emacs to code workspace (workspace 2)
        assigns."\"2  code\"" = [{ class = "Emacs"; }];
      };
  };
}
