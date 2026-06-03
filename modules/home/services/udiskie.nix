{ config, pkgs, lib, ... }:

{
  options = { };

  config = {
    services.udiskie.enable = true;
    # Sway-exec'd via sway/config.nix startup, NOT auto-started by
    # systemd. The HM-generated unit's Requires=tray.target keeps it
    # from auto-starting (no provider for that target), and the
    # WAYLAND_DISPLAY session-start race lands it in failed state
    # before the budget can recover. Sway exec sidesteps both. See
    # blueman-applet.nix for the longer rationale.
    systemd.user.services.udiskie.Install.WantedBy = lib.mkForce [ ];
  };
}
