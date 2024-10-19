args@{ lib, pkgs, ... }:

let

  packages = [
    pkgs.keepassxc
    pkgs.slack
    pkgs.cachix
    pkgs.gnumake
    pkgs.imagemagick
    pkgs.nixpkgs-review
    pkgs.nmap
    pkgs.git-crypt
    pkgs.obsidian
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
    pkgs.neofetch
    pkgs.nix-prefetch-github
    pkgs.pv
    pkgs.ripgrep
    pkgs.shellcheck
    pkgs.terminator
    pkgs.tree
    pkgs.yq
    (pkgs.emacsWithPackagesFromUsePackage (args.emacsConfig))
    pkgs.sqlite
    pkgs.pgcli
    pkgs.rlwrap
    # all other packages
    pkgs.alsa-utils
    pkgs.pulseaudio
    pkgs.xorg.xdpyinfo
    pkgs.element-desktop
    pkgs.gnome.gnome-screenshot
    pkgs.google-chrome
    pkgs.xarchiver
    pkgs.xfce.thunar
    pkgs.xfce.thunar-volman
    pkgs.xfce.thunar-archive-plugin
    pkgs.xfce.tumbler # For image previews in Thunar. Can be handled with a dependency derivation I assume(?)
    pkgs.xfce.xfconf # For saving preferences of Thunar.
    pkgs.libnotify # To use dunst
    pkgs.libsForQt5.qtstyleplugins
    pkgs.lshw
    pkgs.spotify
    pkgs.vlc
    pkgs.ffmpeg-full
    pkgs.pavucontrol
    pkgs.playerctl
    pkgs.xdotool
    pkgs.qt5ct
    pkgs.acpi
    pkgs.arandr
    pkgs.discord
    pkgs.dunst
    pkgs.dconf
    pkgs.gnome.nautilus
    pkgs.keepmenu
    pkgs.lsof
    pkgs.netcat-gnu
    pkgs.nix-diff
    pkgs.nixfmt-classic
    pkgs.pgcli
    pkgs.rclone
    pkgs.signing-party
    pkgs.ssh-to-pgp
    pkgs.xfce.xfconf
    pkgs.xorg.xkill
    pkgs.lxappearance
    pkgs.arc-theme
    pkgs.gnome.adwaita-icon-theme
    pkgs.papirus-icon-theme
    pkgs.paper-icon-theme
    pkgs.ranger
    pkgs.nodejs
    (lib.hiPrio pkgs.insomnia)
    pkgs.nixpkgs-fmt
    pkgs.gh
    pkgs.openvpn
    pkgs.xorg.libxcvt
    pkgs.nil
  ];

  programs = {
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
    broot = { enable = false; };
    command-not-found = { enable = true; };
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    gpg = { enable = true; };
    home-manager = { enable = true; };
    jq = { enable = true; };
  };
  services = {
    blueman-applet = { enable = true; };
    gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
    };
    kdeconnect = {
      enable = true;
      indicator = true;
    };
    playerctld = { enable = true; };
    udiskie = { enable = true; };
  };

in {
  inherit programs services;
  home = {
    inherit packages;
    stateVersion = "24.05";
  };

  xdg.configFile."pgcli/config".text = builtins.readFile ./config/pgcli;
}
