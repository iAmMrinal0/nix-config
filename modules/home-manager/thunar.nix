{ ... }:

# Thunar keeps its preferences in xfconf (xfce4/xfconf/xfce-perchannel-xml/
# thunar.xml). Thunar rewrites that file at runtime for window geometry,
# toolbar layout, sort order, etc. — so we deliberately do NOT own the whole
# file (that would fight the runtime writes the same way managing
# gtk-3.0/bookmarks as a store symlink does; see the note in gtk.nix).
#
# Instead xfconf.settings asserts only the preference keys we care about via
# xfconf-query at activation, leaving the geometry/layout keys mutable. This
# needs the xfconf daemon at runtime, which Thunar already pulls in.
{
  # xfconf.settings only takes effect when xfconf.enable is set (the module's
  # config is mkIf (enable && settings != {})). The xfconf-query it runs at
  # activation needs xfconfd reachable on the session bus, which is why
  # programs.xfconf.enable is also set at the system level in
  # modules/nixos/wayland-session.nix.
  xfconf.enable = true;
  xfconf.settings = {
    thunar = {
      "misc-single-click" = true;
      "misc-open-new-window-as-tab" = true;
      "misc-parallel-copy-mode" = "THUNAR_PARALLEL_COPY_MODE_ALWAYS";
      "misc-show-delete-action" = true;
      "misc-full-path-in-tab-title" = true;
      "misc-confirm-close-multiple-tabs" = false;
      "last-show-hidden" = true;
    };
  };
}
