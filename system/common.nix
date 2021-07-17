{ lib, pkgs, ... }:

let
  systems = {
    darwin = "x86_64-darwin";
    linux = "x86_64-linux";
  };
  linux = import ./linux.nix { inherit lib pkgs; };
  osx = import ./osx.nix { inherit pkgs; };
  zshCustom = pkgs.callPackage ../config/modSteeefZsh.nix { };

  packages = [
    pkgs.keepassxc
    pkgs.slack
    pkgs.kube-score
    pkgs.kubeval
    pkgs.stern
    pkgs.dhall
    pkgs.dhall-json
    pkgs.dhall-lsp-server
    pkgs.haskellPackages.dhall-yaml
    pkgs.haskellPackages.hlint
    pkgs.haskellPackages.haskell-language-server
    pkgs.haskellPackages.stylish-haskell
    pkgs.cachix
    pkgs.gnumake
    pkgs.google-cloud-sdk
    pkgs.imagemagick
    pkgs.kafkacat
    pkgs.nix-review
    pkgs.nmap
    pkgs.pciutils
    pkgs.unzip
    pkgs.xclip
    pkgs.aspellDicts.en
    pkgs.aspellDicts.en-computers
    pkgs.aspell
    pkgs.spago
    pkgs.xsel
    pkgs.ag
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
    pkgs.tree
    pkgs.yq
  ];

  programs = {
    broot = { enable = true; };
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };
    firefox = import ../config/firefox.nix { inherit lib pkgs systems; };
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    git = import ../config/git.nix;
    gpg = { enable = true; };
    home-manager = { enable = true; };
    htop = import ../config/htop.nix;
    jq = { enable = true; };
    kitty = import ../config/kitty.nix { inherit pkgs; };
    tmux = import ../config/tmux.nix { inherit lib pkgs systems; };
    zathura = { enable = true; };
    zsh = import ../config/zsh.nix { inherit lib pkgs systems zshCustom; };
  };

  home = {
    packages = packages;
    sessionVariables = { };
  };
in {
  programs = pkgs.lib.recursiveUpdate (pkgs.lib.recursiveUpdate programs
    (lib.optionalAttrs (builtins.currentSystem == systems.linux)
      linux.programs))
    (lib.optionalAttrs (builtins.currentSystem == systems.darwin) osx.programs);
  home = {
    packages = home.packages
      ++ (lib.optionals (builtins.currentSystem == systems.linux)
        linux.home.packages)
      ++ (lib.optionals (builtins.currentSystem == systems.darwin)
        osx.home.packages);
    sessionVariables = pkgs.lib.recursiveUpdate home.sessionVariables
      (lib.optionalAttrs (builtins.currentSystem == systems.darwin)
        osx.home.sessionVariables);
  };
  extras = (lib.optionalAttrs (builtins.currentSystem == systems.darwin) {
    nixpkgs = osx.nixpkgs;
  }) // (lib.optionalAttrs (builtins.currentSystem == systems.linux) {
    gtk = linux.gtk;
    xsession = linux.xsession;
    qt = linux.qt;
    services = linux.services;
    systemd = linux.systemd;
  });
}
