args@{ lib, pkgs, ... }:

let
  linux = import ./system/linux.nix { inherit lib pkgs; };

  packages = [
    pkgs.keepassxc
    pkgs.slack
    pkgs.dhall
    pkgs.dhall-json
    pkgs.dhall-lsp-server
    pkgs.haskellPackages.dhall-yaml
    pkgs.cachix
    pkgs.gnumake
    pkgs.imagemagick
    pkgs.nixpkgs-review
    pkgs.nmap
    pkgs.pciutils
    pkgs.unzip
    pkgs.xclip
    pkgs.aspellDicts.en
    pkgs.aspellDicts.en-computers
    pkgs.aspell
    pkgs.xsel
    pkgs.silver-searcher
    pkgs.awscli
    pkgs.bc
    pkgs.coreutils-full
    pkgs.dnsutils
    pkgs.drive
    pkgs.neofetch
    pkgs.niv
    pkgs.nix-prefetch-github
    pkgs.pv
    pkgs.ripgrep
    pkgs.shellcheck
    pkgs.stow
    pkgs.terminator
    pkgs.terraform
    pkgs.tree
    pkgs.yq
    (pkgs.emacsWithPackagesFromUsePackage (args.emacsConfig))
    pkgs.sqlite
    pkgs.pgcli
    pkgs.rlwrap
  ];

  programs = {
    broot = { enable = false; };
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };
    firefox = import ./config/firefox.nix { inherit lib pkgs; };
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    git = import ./config/git.nix;
    gpg = { enable = true; };
    home-manager = { enable = true; };
    htop = import ./config/htop.nix;
    jq = { enable = true; };
    kitty = import ./config/kitty.nix { inherit pkgs; };
    tmux = import ./config/tmux.nix { inherit lib pkgs; };
    zathura = import ./config/zathura.nix;
    zsh = import ./config/zsh.nix {
      inherit (args)
        lib pkgs zsh-autosuggestions zsh-you-should-use
        zsh-history-substring-search zsh-nix-shell;
    };
  };

  home = { packages = packages; };
in
{
  programs = lib.recursiveUpdate programs linux.programs;
  home = {
    packages = home.packages ++ linux.home.packages;
    stateVersion = "22.11";
  };
  gtk = linux.gtk;
  xsession = linux.xsession;
  # qt = linux.qt;
  services = linux.services;
  systemd = linux.systemd;
  xdg.configFile."keepassxc/keepassxc.ini".source = ./config/keepassxc.ini;
}
