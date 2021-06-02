{ config, pkgs, lib, ... }:

let
  # brotab = callPackage ./pkgs/brotab { };
  keepmenu = pkgs.callPackage ./pkgs/keepmenu { };
  rofimoji = pkgs.callPackage ./pkgs/rofimoji { };

  wallpaper = lib.readFile (pkgs.callPackage ./scripts/wallpaper.nix { });
  lock = pkgs.callPackage ./scripts/lock.nix { };

  i3blocksConf = pkgs.callPackage ./config/i3blocks.nix { };
  zshCustom = pkgs.callPackage ./config/modSteeefZsh.nix { };

  haskellTools = [
    pkgs.haskellPackages.hlint
    pkgs.haskellPackages.haskell-language-server
    pkgs.haskellPackages.stylish-haskell
  ];

  themes = [
    pkgs.lxappearance
    pkgs.arc-theme
    pkgs.gnome3.defaultIconTheme
    pkgs.papirus-icon-theme
    pkgs.hicolor_icon_theme
    pkgs.material-icons
    pkgs.paper-icon-theme
  ];

in {
  xsession = {
    enable = true;
    initExtra = wallpaper;
    windowManager.i3 = import ./config/i3config.nix { inherit pkgs lib i3blocksConf keepmenu rofimoji; };
  };

  services = {
    blueman-applet = { enable = true; };
    dunst = import ./config/dunstrc.nix { inherit pkgs; };
    gpg-agent = { enable = true; };
    kdeconnect = { enable = true; indicator = true; };
    keybase = { enable = true; };
    lorri = { enable = true; };
    pasystray = { enable = true; };
    picom = import ./config/picom.nix { inherit pkgs; };
    playerctld = { enable = true; };
    udiskie = { enable = true; };
  };

  gtk = import ./config/gtk.nix { inherit pkgs; };

  programs = {
    autorandr = import ./config/autorandr.nix { inherit lib wallpaper; };
    broot = { enable = true; };
    chromium = import ./config/chromium.nix;
    command-not-found.enable = true;
    direnv = { enable = true; enableZshIntegration = true; };
    feh = import ./config/feh.nix;
    firefox = import ./config/firefox.nix { inherit pkgs; };
    fzf = { enable = true; enableZshIntegration = true; };
    git = import ./config/git.nix;
    gpg = { enable = true; };
    home-manager = { enable = true; };
    htop = import ./config/htop.nix;
    jq = { enable = true; };
    kitty = import ./config/kitty.nix { inherit pkgs; };
    rofi = import ./config/rofi.nix { inherit pkgs; };
    tmux = import ./config/tmux.nix { inherit pkgs; };
    zathura = { enable = true; };
    zsh = import ./config/zsh.nix { inherit pkgs zshCustom; };
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = {
      package = pkgs.adwaita-qt;
      name = "adwaita-dark";
    };
  };

  home.packages = themes ++ [ # Media
    pkgs.spotify
    pkgs.vlc
    pkgs.ffmpeg-full
    pkgs.pavucontrol
    pkgs.playerctl
  ] ++ [ # GUI
    pkgs.authy
    pkgs.xorg.xdpyinfo
    pkgs.element-desktop
    pkgs.gnome3.gnome-screenshot
    pkgs.keepassxc
    pkgs.keybase
    pkgs.rescuetime
    pkgs.slack
    pkgs.xarchiver
    pkgs.xfce.thunar
    pkgs.xfce.thunar-volman
    pkgs.xfce.thunar-archive-plugin
    pkgs.xfce.tumbler # For image previews in Thunar. Can be handled with a dependency derivation I assume(?)
    pkgs.xfce.xfconf # For saving preferences of Thunar.
  ] ++ haskellTools ++ [ # Kubernetes
    pkgs.kube-score
    pkgs.kubernetes
    pkgs.kubeval
    pkgs.stern
  ] ++ [ # Dhall
    pkgs.dhall
    pkgs.dhall-json
    pkgs.dhall-lsp-server
    pkgs.haskellPackages.dhall-yaml
  ] ++ [ # Build tools and other dependencies + rarely used
    pkgs.cachix
    pkgs.gnumake
    pkgs.google-cloud-sdk
    pkgs.imagemagick
    pkgs.kafkacat
    pkgs.libnotify # To use dunst
    pkgs.libsForQt5.qtstyleplugins
    pkgs.lshw
    pkgs.nix-review
    pkgs.nmap
    pkgs.pciutils
    pkgs.qt5ct
    pkgs.unzip
    pkgs.xclip
    pkgs.xdotool
    pkgs.aspellDicts.en
    pkgs.aspellDicts.en-computers
    pkgs.aspell
    pkgs.spago
    pkgs.xsel
  ] ++ [ # Bit more frequently used
    pkgs.acpi
    pkgs.ag
    pkgs.arandr
    pkgs.awscli
    pkgs.bc
    pkgs.discord
    pkgs.dnsutils
    pkgs.nodejs-12_x
    pkgs.drive
    pkgs.dunst
    pkgs.gnome3.dconf
    pkgs.gnome3.nautilus
    pkgs.google-drive-ocamlfuse
    keepmenu
    pkgs.lsof
    pkgs.neofetch
    pkgs.netcat-gnu
    pkgs.niv
    pkgs.nix-diff
    pkgs.nix-prefetch-github
    pkgs.nixfmt
    pkgs.pgp-tools
    pkgs.pv
    pkgs.ripgrep
    pkgs.screenfetch
    pkgs.shellcheck
    pkgs.ssh-to-pgp
    pkgs.stow
    pkgs.transmission-gtk
    pkgs.tree
    pkgs.xfce.xfconf
    pkgs.xorg.xkill
    pkgs.yq
  ];

  systemd.user.services = {
    mpris-proxy = {
      Unit.Description = "Mpris proxy";
      Unit.After = [ "network.target" "sound.target" ];
      Service.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
      Install.WantedBy = [ "default.target" ];
    };
    rescuetime = {
      Unit = {
        Description = "Rescuetime Systemd Service";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Environment =
          let toolPaths = lib.makeBinPath [ pkgs.coreutils-full pkgs.gnugrep pkgs.xorg.xprop pkgs.procps pkgs.gawk pkgs.nettools ];
          in [ "PATH=${toolPaths}" ];
        ExecStart = "${pkgs.rescuetime}/bin/rescuetime";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  systemd.user.startServices = true;

}
