{ pkgs, lib, inputs }:

let
in with pkgs; [
  # Development Tools
  eza
  cachix
  gnumake
  nixpkgs-review
  nmap
  git-crypt
  pciutils
  silver-searcher
  awscli
  shellcheck
  nixfmt-classic
  gh
  nil
  btop
  unzip

  # Text Processing & Search
  ripgrep
  tree
  yq
  jq

  # System Utils
  coreutils-full
  dnsutils
  pv
  lshw
  acpi
  lsof
  netcat-gnu
  nix-diff
  xorg.xkill
  nvd

  # Security & Authentication
  keepassxc
  signing-party
  ssh-to-pgp
  openvpn
  rbw
  rofi-rbw

  # Development Environment
  sqlite
  pgcli
  rlwrap
  nodejs
  (lib.hiPrio pkgs.unstable.insomnia)

  # Desktop Environment
  terminator
  google-chrome
  slack
  obsidian
  spotify
  vlc
  discord
  nautilus
  ranger

  # Media & Graphics
  imagemagick
  ffmpeg-full
  gnome-screenshot

  # File Management
  xarchiver
  xfce.thunar
  xfce.thunar-volman
  xfce.thunar-archive-plugin
  xfce.tumbler
  xfce.xfconf
  rclone

  # System Appearance
  lxappearance
  arc-theme
  adwaita-icon-theme
  papirus-icon-theme
  paper-icon-theme

  # Clipboard & Input
  xclip
  xsel
  xdotool

  # Audio
  alsa-utils
  pulseaudio
  pavucontrol
  playerctl

  # Display
  xorg.xdpyinfo
  arandr
  xorg.libxcvt

  # Notification
  libnotify
  dunst

  # Qt & Desktop Integration
  libsForQt5.qtstyleplugins
  libsForQt5.qt5ct
  dconf
  dconf-editor

  # Language & Spellcheck
  aspell
  aspellDicts.en
  aspellDicts.en-computers

  # Network & Communication
  transmission_4-gtk

  # System Information
  neofetch
  nix-prefetch-github
]
