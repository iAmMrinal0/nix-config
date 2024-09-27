{ lib, pkgs, ... }:

let
  keepmenu = pkgs.callPackage ../pkgs/keepmenu { };

  wallpaper = lib.readFile (pkgs.callPackage ../scripts/wallpaper.nix { });

  packages = [
    pkgs.xorg.xdpyinfo
    pkgs.nix-output-monitor
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
    pkgs.nautilus
    pkgs.google-drive-ocamlfuse
    # keepmenu
    pkgs.lsof
    pkgs.netcat-gnu
    pkgs.nix-diff
    pkgs.nixfmt-classic
    pkgs.signing-party # pgp-tools
    pkgs.screenfetch
    pkgs.ssh-to-pgp
    pkgs.xfce.xfconf
    pkgs.xorg.xkill
    pkgs.lxappearance
    pkgs.arc-theme
    pkgs.adwaita-icon-theme
    pkgs.papirus-icon-theme
    pkgs.hicolor-icon-theme
    pkgs.material-icons
    pkgs.paper-icon-theme
    pkgs.ranger
    pkgs.lorri
    pkgs.nodejs-18_x
    pkgs.gh
    pkgs.pgcli
  ];
  programs = {
    # autorandr = import ../config/autorandr.nix { inherit wallpaper; };
    # chromium = import ../config/chromium.nix;
    command-not-found = { enable = true; };
    feh = import ../config/feh.nix;
    # rofi = import ../config/rofi.nix { inherit pkgs; };
  };
  services = {
    # blueman-applet = { enable = true; };
    # dunst = import ../config/dunstrc.nix { inherit pkgs; };
    gpg-agent = { enable = true; pinentryPackage = pkgs.pinentry-qt; };
    # kdeconnect = {
    #   enable = true;
    #   indicator = true;
    # };
    # keybase = { enable = true; };
    lorri = { enable = true; };
    # pasystray = { enable = true; };
    # picom = import ../config/picom.nix { inherit pkgs; };
    playerctld = { enable = true; };
    # polybar = import ../config/polybar.nix { inherit pkgs; };
    # udiskie = { enable = true; };
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

in {
  inherit programs services systemd;
  home = {
    inherit packages;
    sessionVariables = {
        SSH_AUTH_SOCK = "\${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/ssh-agent}";
    };
  };
  gtk = import ../config/gtk.nix { inherit pkgs; };
  xsession = {
    enable = true;
    initExtra = wallpaper;
    windowManager.i3 =
      import ../config/i3config.nix { inherit pkgs lib keepmenu; };
  };
  qt = {
    enable = true;
    platformTheme = { name = "adwaita"; };
    style = {
      package = pkgs.adwaita-qt;
      name = "adwaita-dark";
    };
  };
}
