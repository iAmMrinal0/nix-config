{ ... }:

# Placeholder so the sway module's directory layout mirrors the i3 module.
# Sway does NOT use i3status-rust: ./config.nix disables the built-in swaybar
# (`bars = []`) and ./waybar.nix provides the bar instead (waybar handles the
# SNI tray properly, which swaybar+i3status-rust did not). If i3 is ever
# retired and the i3status-rust definition needs a new home, it would land
# here.
{ }
