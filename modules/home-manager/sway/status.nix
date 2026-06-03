{ ... }:

# i3status-rust is configured in modules/home-manager/i3/status.nix and shared
# between i3 (X11) and sway (Wayland). Sway's bar in ./config.nix runs the same
# i3status-rs binary against the same generated config file. This file is a
# placeholder so the directory layout mirrors the i3 module; once i3 is retired
# (Phase 4) this is where the i3status-rust definition will move to.
{ }
