{ lib, pkgs, ... }:

let
  i3blocksConf = pkgs.callPackage ../config/i3blocks.nix { };

  keepmenu = pkgs.callPackage ../pkgs/keepmenu { };

  wallpaper = lib.readFile (pkgs.callPackage ../scripts/wallpaper.nix { });

  packages = [
    # pkgs.authy
    pkgs.xorg.xdpyinfo
    pkgs.element-desktop
    pkgs.gnome.gnome-screenshot
    pkgs.google-chrome
    # pkgs.keybase
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
    keepmenu
    pkgs.lsof
    pkgs.netcat-gnu
    pkgs.nix-diff
    pkgs.nixfmt-classic
    pkgs.obs-studio
    pkgs.signing-party
    pkgs.ssh-to-pgp
    # pkgs.transmission-gtk
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
    pkgs.barrier
  ];
  programs = {
    autorandr = import ../config/autorandr.nix { inherit wallpaper; };
    chromium = import ../config/chromium.nix;
    command-not-found = { enable = true; };
    feh = import ../config/feh.nix;
    rofi = import ../config/rofi.nix { inherit pkgs; };
  };
  services = {
    blueman-applet = { enable = true; };
    dunst = import ../config/dunstrc.nix { inherit pkgs; };
    gpg-agent = { enable = true; pinentryPackage = pkgs.pinentry-gnome3; };
    kdeconnect = {
      enable = true;
      indicator = true;
    };
    # keybase = { enable = true; };
    lorri = { enable = true; };
    # pasystray = { enable = true; };
    picom = import ../config/picom.nix { inherit pkgs; };
    playerctld = { enable = true; };
    polybar = import ../config/polybar.nix { inherit pkgs; };
    udiskie = { enable = true; };
  };
  systemd = {
    user = {
      startServices = true;
      services = {
        mpris-proxy = {
          Unit.Description = "Mpris proxy";
          Unit.After = [ "network.target" "sound.target" ];
          Service.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
  };

in
{
  inherit programs services systemd;
  home = {
    inherit packages;
    sessionVariables = { };
  };
  gtk = import ../config/gtk.nix { inherit pkgs; };
  xsession = {
    enable = true;
    initExtra = wallpaper;
    windowManager.i3 =
      import ../config/i3config.nix { inherit pkgs lib keepmenu i3blocksConf; };
  };
  # qt = {
  #   enable = true;
  #   platformTheme = "gnome";
  #   style = {
  #     package = pkgs.adwaita-qt;
  #     name = "adwaita-dark";
  #   };
  # };
}
