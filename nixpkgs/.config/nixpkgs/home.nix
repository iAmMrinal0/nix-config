{ config, pkgs, ... }:

with pkgs;

let
  brotab = callPackages ./pkgs/brotab { };
  keepmenu = callPackages ./pkgs/keepmenu { };
  rofimoji = callPackages ./pkgs/rofimoji { };
  wallpaper = import ./scripts/wallpaper.nix { inherit pkgs; };
  easyPS = import (pkgs.fetchFromGitHub {
    owner = "justinwoo";
    repo = "easy-purescript-nix";
    rev = "bad807ade1314420a52c589dbc3d64d3c9b38480";
    sha256 = "099dpxrpch8cgy310svrpdcad2y1qdl6l782mjpcgn3rqgj62vsf";
  });

  i3blocksConf = import ./config/i3blocks.nix { inherit pkgs; };
  zshCustom = import ./config/modSteeefZsh.nix { inherit pkgs; };

  ghcide = (import (builtins.fetchTarball "https://github.com/hercules-ci/ghcide-nix/tarball/master") {}).ghcide-ghc865;

  fonts = [
    cantarell-fonts
    dejavu_fonts
    emacs-all-the-icons-fonts
    font-awesome_4
    google-fonts
    noto-fonts
  ];

  haskellTools = [
    haskellPackages.hlint
    haskellPackages.stylish-haskell
    ghcide
  ];
in {

  xsession = {
    enable = true;
    initExtra = lib.readFile wallpaper;
    windowManager.i3 = import ./config/i3config.nix { inherit pkgs i3blocksConf keepmenu rofimoji; };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  services.dunst = import ./config/dunstrc.nix { inherit pkgs; };
  services.picom = import ./config/picom.nix { inherit pkgs; };
  services.emacs.enable = true;
  services.lorri.enable = true;
  services.udiskie.enable = true;

  gtk = import ./config/gtk.nix { inherit pkgs; };
  programs.chromium = import ./config/chromium.nix;
  programs.emacs = import ./config/emacs.nix { inherit pkgs; };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.feh = import ./config/feh.nix;
  programs.git = import ./config/git.nix;
  programs.kitty = import ./config/kitty.nix { inherit pkgs; };
  programs.rofi = import ./config/rofi.nix;
  programs.zsh = import ./config/zsh.nix { inherit pkgs zshCustom; };
  programs.tmux = import ./config/tmux.nix { inherit pkgs; };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # TODO see if there's a better heirarchy for packages
  # TODO manage fonts properly
  # TODO Migrate the configs in the dotfiles repo to nix
  home.packages = fonts ++ [ # Themes and icons
    lxappearance
    arc-theme
    gnome3.defaultIconTheme
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
    xorg.xdpyinfo
    firefox-beta-bin
    gnome3.gnome-screenshot
    keepassxc
    keybase
    rescuetime
    slack
    vscode
    xarchiver
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.tumbler # For image previews in Thunar. Can be handled with a dependency derivation I assume(?)
    xfce.xfconf # For saving preferences of Thunar.
    zathura
  ] ++ haskellTools ++ [ # Languages
    # nodePackages.node2nix
    # nodePackages_10_x.bower
    # nodePackages_10_x.bower2nix
    # nodePackages_10_x.pulp
    # nodejs-10_x
    python36
  ] ++ (with easyPS.inputs; [
    # psc-package
    # purescript
    # spago
  ]) ++ [
    kubernetes
    stern
  ] ++ [ # Build tools and other dependencies + rarely used
    gnumake
    google-cloud-sdk
    imagemagick
    libnotify # To use dunst
    libsForQt5.qtstyleplugins
    lshw
    nmap
    pciutils
    python36Packages.virtualenv
    python36Packages.pip
    unzip
    xclip
    xdotool
    xsel
  ] ++ [ # Bit more frequently used
    acpi
    ag
    arandr
    autorandr
    awscli
    bc
    brotab
    discord
    drive
    dunst
    glow
    gnome3.dconf
    gnome3.nautilus
    google-drive-ocamlfuse
    htop
    jq
    keepmenu
    lsof
    neofetch
    pv
    ripgrep
    screenfetch
    shellcheck
    stow
    transmission-gtk
    xfce.xfconf
    xorg.xkill
  ];
}
