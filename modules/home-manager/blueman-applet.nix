{ lib, ... }:

{
  # blueman-applet is launched by sway exec (see sway/config.nix
  # startup) — NOT auto-started via systemd. The HM-generated unit
  # carries `Requires=tray.target` and `WantedBy=graphical-session.target`,
  # and tray.target isn't activated by anything in our session graph,
  # so auto-start hangs waiting on a target that never fires.
  # Combined with the original WAYLAND_DISPLAY race at session start
  # (units fail-fast before env propagates, exhaust StartLimitBurst,
  # land in failed state) the systemd path was net-worse for these
  # tray apps than just exec'ing them from sway. Sway-exec gets them
  # the right env at the right time and they don't need singleton
  # enforcement (unlike waybar / kanshi, which are still systemd-
  # managed).
  services.blueman-applet.enable = true;
  systemd.user.services.blueman-applet.Install.WantedBy = lib.mkForce [ ];

  dconf.settings."org/blueman/general" = {
    plugin-list = [ "!ConnectionNotifier" ];
  };
}
