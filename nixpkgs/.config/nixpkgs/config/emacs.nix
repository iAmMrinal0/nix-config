{ pkgs, ... }:

let
  package = pkgs.emacs;
  emacsPackages = pkgs.emacsPackagesNgGen package;
  emacsWithPackages = emacsPackages.emacsWithPackages (epkgs: (with epkgs.elpaPackages; [
    rainbow-mode
  ]) ++ (with epkgs.melpaPackages; [
    ace-window
    ag
    all-the-icons
    anzu
    avy
    bind-key
    diminish
    direnv
    elpy
    exec-path-from-shell
    expand-region
    flycheck
    free-keys
    git-gutter
    gruvbox-theme
    haskell-mode
    helm
    helm-ag
    helm-projectile
    hindent
    hungry-delete
    hydra
    intero
    jedi
    js2-mode
    js2-refactor
    keychain-environment
    keyfreq
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
    py-autopep8
    rainbow-delimiters
    smart-mode-line
    smartparens
    tern
    tern-auto-complete
    use-package
    which-key
    yaml-mode
    yasnippet
    zop-to-char
  ]));

in { home.packages = [emacsWithPackages]; }
