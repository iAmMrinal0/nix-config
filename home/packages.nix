{ pkgs, lib, inputs, osConfig }:

# Both transmission GUIs are installed (see the transmission_4-* entries at
# the end): transmission_4-qt is the sway choice — it publishes a proper SNI
# tray item; the GTK build's StatusIcon API is X11-only — and transmission_4-gtk
# is the i3 choice. The session picker means one generation can boot either WM,
# so the GUI can't be chosen at build time; each WM's startup launches the right
# one (modules/home-manager/i3/config.nix → gtk, .../sway/config.nix → qt).
with pkgs; [
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
  ddcutil
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
  rofi-rbw
  wtype # rofi-rbw autotype under sway; xdotool covers i3

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
  # Wayland screenshots are grim+slurp+satty, script-pinned in
  # modules/home-manager/sway/config.nix (Print binding) — no package
  # entry needed. gnome-screenshot stays for the mordor (X11/i3) host
  # where Print is bound to gnome-screenshot -i. flameshot was tried in
  # between; its Wayland multi-monitor workaround lives in commit 2896832.

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
  my.scripts.tnas-health

  gemini-cli
  inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk
  python3
  python3Packages.pip

  # Transmission GUI for both stacks (see header) — gtk for i3, qt for sway.
  # Installed unconditionally so PATH carries the right binary whichever WM
  # the picker boots; each WM's startup execs its variant by full store path.
  #
  # Both variants are built from the same transmission core, so they ship
  # identical shared files (lib/systemd/system/transmission-daemon.service,
  # the transmission-daemon/transmission-remote/transmission-cli binaries,
  # man pages). In home.packages' buildEnv that's a path collision. lowPrio
  # on the gtk variant lets the qt variant win those shared files while both
  # unique GUI binaries (transmission-gtk, transmission-qt) stay in PATH.
  (lib.lowPrio transmission_4-gtk)
  transmission_4-qt
]
