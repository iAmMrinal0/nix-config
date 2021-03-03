{ config, pkgs, lib, ... }:

with pkgs;

let
  # brotab = callPackage ./pkgs/brotab { };
  keepmenu = callPackage ./pkgs/keepmenu { };
  rofimoji = callPackage ./pkgs/rofimoji { };

  wallpaper = callPackage ./scripts/wallpaper.nix { };
  lock = callPackage ./scripts/lock.nix { };

  i3blocksConf = callPackage ./config/i3blocks.nix { };
  zshCustom = callPackage ./config/modSteeefZsh.nix { };

  haskellTools = [
    haskellPackages.hlint
    haskellPackages.haskell-language-server
    haskellPackages.stylish-haskell
  ];
in {

  xsession = {
    enable = true;
    initExtra = lib.readFile wallpaper;
    windowManager.i3 = import ./config/i3config.nix { inherit pkgs lib i3blocksConf keepmenu rofimoji; };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

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
  services.screen-locker = {
    enable = true;
    enableDetectSleep = true;
    inactiveInterval = 15;
    lockCmd = "${lock}";
  };
  # services.emacs = {
  #   enable = true;
  #   package = pkgs.emacsGcc;
  #   socketActivation.enable = true;
  #   client = {
  #     enable = true;
  #     arguments = ["-a" "\"\"" "-c"];
  #   };
  # };
  services.lorri.enable = true;
  services.udiskie.enable = true;

  gtk = import ./config/gtk.nix { inherit pkgs; };

  programs.autorandr = {
    enable = true;
    hooks = {
      postswitch = {
        "change-background" = lib.readFile wallpaper;
      };
    };
  };
  programs.chromium = import ./config/chromium.nix;
  programs.command-not-found.enable = true;
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.feh = import ./config/feh.nix;
  programs.gpg.enable = true;
  programs.git = import ./config/git.nix;
  programs.kitty = import ./config/kitty.nix { inherit pkgs; };
  programs.rofi = import ./config/rofi.nix { inherit pkgs; };
  qt = {
    enable = true;
    platformTheme = "gtk";
  };
  programs.zsh = import ./config/zsh.nix { inherit pkgs zshCustom; };
  programs.tmux = import ./config/tmux.nix { inherit pkgs; };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # TODO see if there's a better heirarchy for packages
  # TODO Migrate the configs in the dotfiles repo to nix
  home.packages = [ # Themes and icons
    lxappearance
    arc-theme
    gnome3.defaultIconTheme
    capitaine-cursors
    papirus-icon-theme
    hicolor_icon_theme
    material-icons
    paper-icon-theme
  ] ++ [ # Media
    spotify
    vlc
  ] ++ [ # Media in terminal
    ffmpeg-full
    pavucontrol
    playerctl
  ] ++ [ # GUI
    authy
    xorg.xdpyinfo
    firefox
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
    zathura
  ] ++ haskellTools ++ [
    kubernetes
    stern
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
    perl # for i3blocks scripts
    python36Packages.virtualenv
    python36Packages.pip
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
    htop
    jq
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
