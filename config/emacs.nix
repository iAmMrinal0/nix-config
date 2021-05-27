{ pkgs, ... }:

{
  config = "${pkgs.fetchFromGitHub {
    owner = "iammrinal0";
    repo = ".emacs.d";
    rev = "09f043b08f12c89d77272a7c16848a5f87858dec";
    sha256 = "0w8frn5m47hl1xs9z2q6n7xp6sxl7yl321s0fq7pzs4zyvn7z5p6";
  }}/init.el";
  package = pkgs.emacsGcc;
  extraEmacsPackages = epkgs: (with epkgs; [
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
    hasky-extensions
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
