{ ... }:

# Flameshot config for Wayland (sway).
#
# useGrimAdapter=true switches flameshot from the xdg-desktop-portal D-Bus
# capture path to calling `grim` directly. On sway/wlroots the grim
# adapter is the upstream-recommended Wayland mode — fewer protocol hops,
# more reliable multi-monitor handling, and no portal-prompt nag. We
# already ship grim + slurp + wl-clipboard via wayland-session.nix.
#
# This file is symlinked from /nix/store, so any setting flameshot tries
# to write via its Configuration dialog will silently no-op. If you ever
# want to tweak more flameshot settings (colors, default save path,
# shortcuts), add the keys here rather than via the GUI.
{
  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    useGrimAdapter=true
    # Suppresses the "grim's screenshot component is implemented based on
    # wlroots, it may not be used in gnome..." notification that fires
    # every time the grim adapter runs. Per flameshot PR #3456 — the
    # spelling really is "disabled" (not "disable").
    disabledGrimWarning=true
  '';
}
