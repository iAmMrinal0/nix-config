{ config, pkgs, username, ... }:

{
  gtk = {
    enable = true;
    font.package = pkgs.cantarell-fonts;
    font.name = "Cantarell Regular 12";
    iconTheme.package = pkgs.papirus-icon-theme;
    iconTheme.name = "Papirus";
    cursorTheme.package = pkgs.bibata-cursors;
    cursorTheme.name = "Bibata-Modern-Classic";
    cursorTheme.size = 24;
    theme.package = pkgs.gruvbox-gtk-theme;
    theme.name = "Gruvbox-Dark";
    # 26.05 changed the default of gtk4.theme from config.gtk.theme to
    # null. Now that we're on stateVersion 26.05, pin it explicitly to the
    # gtk3 theme so GTK4 apps stay on Gruvbox-Dark (the new default would
    # otherwise leave them unthemed).
    gtk4.theme = config.gtk.theme;
    gtk2.extraConfig = ''
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

  # GTK file pickers / Thunar REWRITE ~/.config/gtk-3.0/bookmarks at runtime
  # (any "add to bookmarks" click), turning it back into a regular file. On
  # the next activation HM tries to back it up, finds the .hm-backup from
  # last time already there, and ABORTS THE WHOLE ACTIVATION — every unit
  # file and .wants link in $HOME then silently stays at the previous
  # generation (this masked the waybar sway-session.target fix entirely).
  # Bookmarks are declarative here by choice, so force-overwrite instead of
  # backing up; runtime bookmark edits are discarded at activation.
  xdg.configFile."gtk-3.0/bookmarks".force = true;
}
