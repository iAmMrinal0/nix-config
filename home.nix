{ config, pkgs, lib, ... }:

with pkgs;

let
  # brotab = callPackage ./pkgs/brotab { };
  keepmenu = callPackage ./pkgs/keepmenu { };
  rofimoji = callPackage ./pkgs/rofimoji { };

  wallpaper = lib.readFile (callPackage ./scripts/wallpaper.nix { });
  lock = callPackage ./scripts/lock.nix { };

  i3blocksConf = callPackage ./config/i3blocks.nix { };
  zshCustom = callPackage ./config/modSteeefZsh.nix { };

  haskellTools = [
    haskellPackages.hlint
    haskellPackages.haskell-language-server
    haskellPackages.stylish-haskell
  ];

  themes = [
    lxappearance
    arc-theme
    gnome3.defaultIconTheme
    capitaine-cursors
    papirus-icon-theme
    hicolor_icon_theme
    material-icons
    paper-icon-theme
  ];

in {
  xsession = {
    enable = true;
    initExtra = wallpaper;
    windowManager.i3 = import ./config/i3config.nix { inherit pkgs lib i3blocksConf keepmenu rofimoji; };
  };


  services.blueman-applet.enable = true;
  services.dunst = import ./config/dunstrc.nix { inherit pkgs; };
  services.gpg-agent.enable = true;
  services.picom = import ./config/picom.nix { inherit pkgs; };
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };
  services.keybase.enable = true;
  services.pasystray.enable = true;
  services.lorri.enable = true;
  services.udiskie.enable = true;

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
      package = adwaita-qt;
      name = "adwaita-dark";
    };
  };

  home.packages = themes ++ [ # Media
    spotify
    vlc
  ] ++ [ # Media in terminal
    ffmpeg-full
    pavucontrol
    playerctl
  ] ++ [ # GUI
    authy
    xorg.xdpyinfo
    element-desktop
    gnome3.gnome-screenshot
    keepassxc
    keybase
    rescuetime
    slack
    xarchiver
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.tumbler # For image previews in Thunar. Can be handled with a dependency derivation I assume(?)
    xfce.xfconf # For saving preferences of Thunar.
  ] ++ haskellTools ++ [
    kube-score
    kubernetes
    kubeval
    stern
  ] ++ [
    dhall
    dhall-json
    dhall-lsp-server
    haskellPackages.dhall-yaml
  ] ++ [ # Build tools and other dependencies + rarely used
    cachix
    gnumake
    google-cloud-sdk
    imagemagick
    kafkacat
    libnotify # To use dunst
    libsForQt5.qtstyleplugins
    lshw
    nix-review
    nmap
    pciutils
    qt5ct
    unzip
    xclip
    xdotool
    aspellDicts.en
    aspellDicts.en-computers
    aspell
    xsel
  ] ++ [ # Bit more frequently used
    acpi
    ag
    arandr
    awscli
    bc
    discord
    dnsutils
    nodejs-12_x
    drive
    dunst
    gnome3.dconf
    gnome3.nautilus
    google-drive-ocamlfuse
    keepmenu
    lsof
    neofetch
    netcat-gnu
    niv
    nix-diff
    nix-prefetch-github
    nixfmt
    pv
    ripgrep
    screenfetch
    shellcheck
    stow
    transmission-gtk
    tree
    xfce.xfconf
    xorg.xkill
    yq
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
