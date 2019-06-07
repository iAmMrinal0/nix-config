{pkgs, ...}:

with pkgs;

{
  enable = true;
  font.package = cantarell-fonts;
  font.name = "Cantarell 11";
  iconTheme.package = paper-icon-theme;
  iconTheme.name = "Paper";
  theme.package = shades-of-gray-theme;
  theme.name = "Shades-of-gray-Firebrick";
  gtk2.extraConfig = ''
    gtk-cursor-theme-size=0
    gtk-toolbar-style=GTK_TOOLBAR_BOTH
    gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
    gtk-button-images=1
    gtk-menu-images=1
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=1
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintfull
    gtk-xft-rgba=rgb'';
  gtk3.extraConfig = {
    gtk-application-prefer-dark-theme="1";
    gtk-cursor-theme-name="Paper";
    gtk-cursor-theme-size="0";
    gtk-toolbar-style="GTK_TOOLBAR_BOTH";
    gtk-toolbar-icon-size="GTK_ICON_SIZE_LARGE_TOOLBAR";
    gtk-button-images="1";
    gtk-menu-images="1";
    gtk-enable-event-sounds="0";
    gtk-enable-input-feedback-sounds="0";
    gtk-xft-antialias="1";
    gtk-xft-hinting="1";
    gtk-xft-hintstyle="hintfull";
    gtk-xft-rgba="rgb";
  };
}
