{ pkgs, lib, inputs, osConfig }:

let
  # On Wayland hosts (betazed) transmission_4-qt is the GUI of choice (it
  # publishes a proper SNI tray item; the GTK build's StatusIcon API is
  # X11-only). On X11 hosts (mordor → i3) transmission_4-gtk stays in for
  # parity with the i3 setup.
  isWayland = osConfig.modules.wayland.registerSession or false;
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
  # flameshot is the Wayland-era replacement for gnome-screenshot's
  # interactive picker. It uses xdg-desktop-portal (configured in
  # modules/nixos/wayland-session.nix) to ask sway for the frames, then
  # opens its annotation editor for save-or-copy. Bound to Print in
  # modules/home-manager/sway/config.nix. gnome-screenshot stays for the
  # mordor (X11/i3) host where Print is bound to gnome-screenshot -i.
  flameshot

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
  # Kirigami / KF6 styling so KDE apps render correctly outside Plasma:
  # qqc2-desktop-style is the QtQuick Controls QML plugin that lets
  # Kirigami widgets pick up the desktop look (referenced via the
  # QT_QUICK_CONTROLS_STYLE=org.kde.desktop env in wayland-session.nix);
  # breeze ships the BreezeDark color scheme that kdeglobals points at
  # (see modules/home-manager/qt.nix). Without both, kdeconnect-app
  # falls back to default Fusion light.
  kdePackages.qqc2-desktop-style
  kdePackages.breeze
  dconf
  dconf-editor

  # Language & Spellcheck
  aspell
  aspellDicts.en
  aspellDicts.en-computers

  # System Information
  # neofetch was removed in 26.05 (unmaintained upstream); fastfetch is
  # the maintained replacement.
  fastfetch
  nix-prefetch-github

  gemini-cli
  inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk
  python3
  python3Packages.pip
] ++ lib.optional (!isWayland) pkgs.transmission_4-gtk
