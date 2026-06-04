{ config, pkgs, username, ... }:

{
  gtk = {
    enable = true;
    font.package = pkgs.cantarell-fonts;
    font.name = "Cantarell Regular 12";
    iconTheme.package = pkgs.papirus-icon-theme;
    iconTheme.name = "Papirus-Dark";
    theme.package = pkgs.gruvbox-gtk-theme;
    theme.name = "Gruvbox-Dark";
    # 26.05 changed the default of gtk4.theme from config.gtk.theme to
    # null. We're still on stateVersion < 26.05 (legacy default), so pin
    # it explicitly to the gtk3 theme to keep GTK4 apps on Gruvbox-Dark
    # and silence the migration warning.
    gtk4.theme = config.gtk.theme;
    gtk2.extraConfig = ''
      gtk-cursor-theme-size=0
      gtk-toolbar-style=GTK_TOOLBAR_BOTH
      gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
      gtk-button-images=1
      gtk-menu-images=1
      gtk-enable-event-sounds=0
      gtk-enable-input-feedback-sounds=0
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle=hintfull
      gtk-xft-rgba=rgb'';
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = "1";
      gtk-cursor-theme-name = "Adwaita";
      gtk-cursor-theme-size = "0";
      gtk-toolbar-style = "GTK_TOOLBAR_BOTH";
      gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
      gtk-button-images = "1";
      gtk-menu-images = "1";
      gtk-enable-event-sounds = "0";
      gtk-enable-input-feedback-sounds = "0";
      gtk-xft-antialias = "1";
      gtk-xft-hinting = "1";
      gtk-xft-hintstyle = "hintfull";
      gtk-xft-rgba = "rgb";
    };
    gtk3.extraCss = ''
      window decoration {
        margin: 0;
        border: none;
      }
      /* regular thunar toolbar icons */
      .thunar {
        -gtk-icon-style: regular;
      }
    '';
    gtk3.bookmarks = [
      "file:///home/${username}/Documents"
      "file:///home/${username}/Downloads"
      "file:///home/${username}/Pictures"
      "file:///home/${username}/Videos"
      "file:///home/${username}/oss"
      "file:///home/${username}/play"
      "file:///home/${username}/work"
    ];
  };
}
