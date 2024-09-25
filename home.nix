args@{ lib, pkgs, ... }:

let
  linux = import ./system/linux.nix { inherit lib pkgs; };

  emacsConfig =
    import ./config/emacs.nix { inherit (args) pkgs emacsConfiguration; };

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
    # pkgs.cachix
    pkgs.gnumake
    pkgs.imagemagick
    pkgs.kafkacat
    pkgs.nixpkgs-review
    pkgs.nmap
    pkgs.pciutils
    pkgs.unzip
    pkgs.xclip
    pkgs.aspellDicts.en
    pkgs.aspellDicts.en-computers
    pkgs.aspell
    pkgs.spago
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
    # pkgs.tree
    pkgs.yq
    (pkgs.emacsWithPackagesFromUsePackage emacsConfig)
    pkgs.ngrok
  ];

  programs = {
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
    broot = { enable = true; };
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };
    # firefox = import ./config/firefox.nix { inherit lib pkgs; };
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
in {
  programs = lib.recursiveUpdate programs linux.programs;
  home = {
    packages = home.packages ++ linux.home.packages;
    sessionVariables = {
        SSH_AUTH_SOCK = "\${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/ssh-agent}";
    };
    file.".config/pgcli/config".text = builtins.readFile ./config/pgcli;
  };
  # xsession = linux.xsession;
  qt = linux.qt;
  services = linux.services;
  # systemd = linux.systemd;
  # xdg.configFile."keepassxc/keepassxc.ini".source = ./config/keepassxc.ini;
}
