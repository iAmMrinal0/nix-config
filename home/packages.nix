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
  # nixfmt-classic is deprecated in 26.05; nixfmt is the maintained
  # RFC-style formatter (note: output style differs from the classic one).
  nixfmt
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
  xkill
  nvd
  socat
  bubblewrap
  sshuttle

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
  # These moved out of the xfce set to top-level in 26.05.
  thunar
  thunar-volman
  thunar-archive-plugin
  tumbler
  xfconf
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
  # 26.05 deprecated the `xorg` package set; xdpyinfo is now top-level.
  xdpyinfo
  arandr
  libxcvt

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
  # neofetch was removed in 26.05 (unmaintained upstream); fastfetch is
  # the maintained replacement.
  fastfetch
  nix-prefetch-github

  gemini-cli
  inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk
  python3
  python3Packages.pip
]
