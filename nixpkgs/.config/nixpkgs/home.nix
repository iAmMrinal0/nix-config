{ config, pkgs, ... }:

with pkgs;

let
  rescuetime-overlay = import ./overlays/rescuetime.nix;
  wallpaper = import ./scripts/wallpaper.nix { inherit pkgs config; };
  easyPS = import (pkgs.fetchFromGitHub {
    owner = "justinwoo";
    repo = "easy-purescript-nix";
    rev = "bad807ade1314420a52c589dbc3d64d3c9b38480";
    sha256 = "099dpxrpch8cgy310svrpdcad2y1qdl6l782mjpcgn3rqgj62vsf";
  });

  fonts = [
    cantarell-fonts
    dejavu_fonts
    fira-code
    font-awesome-ttf
    font-awesome_5
    google-fonts
    hack-font
    hasklig
    hermit
    iosevka
    noto-fonts
  ];
in
rec {
  nixpkgs.overlays = [
    rescuetime-overlay
  ];

  imports = [
    ./config/emacs.nix
  ];

  xsession = {
    enable = true;
    initExtra = lib.readFile wallpaper;
    windowManager.command = "i3";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  services.dunst = {
    enable = true;
    settings = import ./config/dunstrc.nix;
    iconTheme.package = pkgs.numix-icon-theme-circle;
    iconTheme.name = "Numix Circle";
  };

  programs.chromium = import ./config/chromium.nix;
  programs.feh = import ./config/feh.nix;
  programs.rofi = import ./config/rofi.nix;
  programs.zsh = import ./config/zsh.nix { inherit pkgs; };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };


  # TODO zsh setup and icons in notifications
  # TODO see if there's a better heirarchy for packages
  # TODO manage fonts properly
  # TODO Git config
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
    chromium
    gnome3.gnome-screenshot
    keepassxc
    keybase
    rescuetime
    slack
    terminator
    vscode
    xfce.thunar
    zathura
  ] ++ [ # Languages
    ghc
    nodePackages.node2nix
    nodePackages_10_x.bower
    nodePackages_10_x.bower2nix
    nodePackages_10_x.pulp
    nodejs-10_x
    python36
    stack
  ] ++ (with easyPS.inputs; [
    psc-package
    purescript
    spago
  ]) ++ [ # Build tools and other dependencies + rarely used
    fzf
    gnumake
    imagemagick
    libnotify # To use dunst
    nmap
    scrot
    unzip
    xclip
    xdotool
    xfce.tumbler # For image previews in Thunar. Can be handled with a dependency derivation I assume(?)
    xsel
  ] ++ [ # Bit more frequently used
    ag
    arandr
    drive
    dunst
    htop
    jq
    neofetch
    rofi
    screenfetch
    scrot
    stow
    tmux
  ];
}
