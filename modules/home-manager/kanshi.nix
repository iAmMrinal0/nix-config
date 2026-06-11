{ lib, pkgs, config, hostname ? "", ... }:

let
  systemHostName = if hostname != "" then
    hostname
  else if config ? networking.hostName then
    config.networking.hostName
  else
    builtins.getEnv "HOSTNAME";

  hostConfig = if systemHostName != ""
  && builtins.pathExists ./kanshi/${systemHostName}.nix then
    import ./kanshi/${systemHostName}.nix { inherit lib pkgs; }
  else {
    profiles = { };
  };

in {
  services.kanshi = {
    enable = true;
    settings =
      lib.mapAttrsToList (name: profile: { profile = profile // { inherit name; }; })
        hostConfig.profiles;
  };

  # Kanshi is managed exclusively by its systemd user unit (see the HM
  # services.kanshi module — Install.WantedBy = sway-session.target,
  # ConditionEnvironment = WAYLAND_DISPLAY, Restart = always).
  #
  # The earlier setup also exec'd kanshi from sway/config.nix to dodge a
  # WAYLAND_DISPLAY-import race on session start, but HM's activation
  # always starts the systemd unit on every nixos-rebuild regardless of
  # WantedBy, so we ended up with two launchers fighting on every
  # rebuild — and the sway-exec'd one was failing silently while the
  # systemd one would briefly enumerate outputs mid-rebuild and latch
  # onto the `default` profile when the Dell hadn't re-enumerated yet
  # (laptop pinned at 0,0, Dell auto-shoved to the right by sway). The
  # fix is to drop the sway-exec line (in sway/config.nix) and back the
  # systemd unit's retry budget so the original race doesn't refail it.
  #
  # Defaults are StartLimitBurst=5 / StartLimitIntervalSec=10s with
  # RestartSec=100ms — five "failed to connect to display" misses in
  # well under a second exhausts the budget. Bumping RestartSec to 2s
  # spreads retries over the full window so the unit can ride out
  # 5–10s of env-propagation lag at session start without hitting the
  # hard limit.
  systemd.user.services.kanshi.Service.RestartSec = lib.mkForce 2;
  systemd.user.services.kanshi.Unit.StartLimitBurst = lib.mkForce 10;
  systemd.user.services.kanshi.Unit.StartLimitIntervalSec = lib.mkForce 30;

  # Kanshi must serve BOTH Wayland sessions (sway + Hyprland picker
  # entries), but services.kanshi.systemdTarget is a SINGLE string (it
  # defaults to wayland.systemd.target = sway-session.target), so the unit
  # wiring is overridden wholesale here:
  #   - WantedBy both per-WM targets → starts under either compositor.
  #   - PartOf both → stops when either target stops (sway stops its
  #     target on exit via the generated `swaymsg subscribe shutdown`
  #     exec; Hyprland's is stopped by the socket-watcher exec-once in
  #     modules/home-manager/hyprland/config.nix). Without the stop
  #     propagation, kanshi would outlive the compositor, crash on the
  #     dead socket, and Restart=always would burn it into
  #     start-limit-hit against the stale WAYLAND_DISPLAY.
  #   - Requires CLEARED: the stock unit Requires= its one target, which
  #     under the dual-target setup would drag sway-session.target active
  #     when kanshi starts under Hyprland (and vice versa) — exactly the
  #     sticky-target class of bug the per-WM targets exist to prevent.
  #     WantedBy+PartOf cover start and stop; Requires adds nothing here.
  # On hosts without the picker (mordor today) hyprland-session.target
  # doesn't exist; a .wants/.partof reference to a nonexistent target is
  # inert, so this is safe everywhere.
  systemd.user.services.kanshi.Unit.PartOf =
    lib.mkForce [ "sway-session.target" "hyprland-session.target" ];
  systemd.user.services.kanshi.Unit.Requires = lib.mkForce [ ];
  systemd.user.services.kanshi.Unit.After =
    lib.mkForce [ "sway-session.target" "hyprland-session.target" ];
  systemd.user.services.kanshi.Install.WantedBy =
    lib.mkForce [ "sway-session.target" "hyprland-session.target" ];
}
