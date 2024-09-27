{ pkgs, emacsConfiguration, ... }:

{
  config = "${emacsConfiguration}/config.org";
  package = pkgs.emacs-unstable;
  defaultInitFile = true;
  extraEmacsPackages = epkgs:
    (with epkgs; [
      ace-window
      ag
      all-the-icons
      anzu
      avy
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
      # hasky-extensions
      helm
      helm-ag
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
}
