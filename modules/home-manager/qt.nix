{ pkgs, ... }:

# Qt theming sits at the system level via the NixOS qt module
# (modules/nixos/wayland-session.nix → qt.platformTheme = "qtct";
# qt.style = "adwaita-dark"). That module installs qt5ct + qt6ct and
# the Adwaita style plugins for both Qt5 and Qt6, and pushes
# QT_QPA_PLATFORMTHEME / QT_STYLE_OVERRIDE into /etc/pam/environment
# so every Qt app — including sway-exec'd ones whose env never sees
# home.sessionVariables — picks them up.
#
# This file deploys the qt5ct/qt6ct config files. The icon-theme line
# is the load-bearing setting: it's what makes Qt's QIcon resolution
# honor Papirus for mime icons (folder/video/audio) in apps like
# transmission-qt's torrent rows. Without it, Qt falls back to hicolor
# and shows the generic-file glyph for every row.
#
# Why we ditched QT_QPA_PLATFORMTHEME=adwaita: adwaita-qt only ships a
# QStyle plugin (plugins/styles/adwaita.so), not a QPlatformTheme
# plugin (plugins/platformthemes/adwaita.so). Setting that env var
# made Qt look for a platform-theme plugin that doesn't exist anywhere
# in the store; the load failed silently and Qt fell back to the
# default theme with no GTK bridge. qtct is a real platform-theme
# plugin and reads icon-theme + style from its own config below.
#
# The stylesheets= entry below loads a QSS that pins transmission-qt's
# top toolbar icons to 20px (default is 24, which looks oversized at
# 109 DPI / scale 1.0) and restores the inter-button breathing room
# that's lost when the icon shrinks. Selector is QToolBar#toolBar,
# which only matches a QToolBar whose objectName is exactly "toolBar"
# — transmission-qt's main toolbar in qt/MainWindow.ui. Other Qt apps
# would have to use that exact objectName to be affected; none of the
# Qt apps we currently run do. qt5ct/qt6ct's platform-theme plugin
# applies this stylesheet via QApplication::setStyleSheet at app init,
# which is the only injection point transmission-qt's argv handling
# doesn't intercept (it captures -stylesheet PATH as a torrent file).
let
  toolbarIconQss = pkgs.writeText "qt-app-overrides.qss" ''
    /* transmission-qt's main toolbar: shrink the .ui-baked 24px iconSize
       to 20px (oversized at 109 DPI / scale 1.0) and restore the
       button-to-button gap that gets squashed when the icon shrinks. */
    QToolBar#toolBar { qproperty-iconSize: 20px 20px; }
    QToolBar#toolBar QToolButton { padding-left: 6px; padding-right: 6px; }

    /* QMenu items (right-click menus, tray-icon menus like kdeconnect-
       indicator's) default to very tight padding under Adwaita-Dark on
       this Qt build. Add breathing room so menu rows are easy to target. */
    QMenu { padding: 4px; }
    QMenu::item { padding: 6px 24px 6px 12px; min-height: 22px; }
    QMenu::separator { margin: 4px 8px; height: 1px; }
  '';
in
{
  xdg.configFile."qt5ct/qt5ct.conf".text = ''
    [Appearance]
    custom_palette=false
    icon_theme=Papirus
    standard_dialogs=default
    style=Adwaita-Dark

    [Interface]
    stylesheets=${toolbarIconQss}
  '';

  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    custom_palette=false
    icon_theme=Papirus
    standard_dialogs=default
    style=Adwaita-Dark

    [Interface]
    stylesheets=${toolbarIconQss}
  '';

  # KDE color scheme for Kirigami / KF6 apps (kdeconnect-app etc.) running
  # outside Plasma. Adwaita-Dark only reaches traditional QWidget apps via
  # qt5ct/qt6ct; QtQuick / Kirigami doesn't go through QStyle and needs a
  # KDE-style color scheme via kdeglobals. The shipped BreezeDark.colors
  # file is already a complete kdeglobals (has [General] with ColorScheme=
  # plus a full set of [Colors:*] palette rows), so we symlink it as-is
  # rather than duplicating the palette inline. Pairs with QT_QUICK_CONTROLS_STYLE
  # in wayland-session.nix and kdePackages.qqc2-desktop-style in
  # home/packages.nix.
  xdg.configFile."kdeglobals".source =
    "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors";
}
