{ config, lib, pkgs, hostname, ... }:

let
  # `hostname` is always supplied via home-manager.extraSpecialArgs
  # (see home.nix), so we can key the per-host profiles off it directly.
  hostConfig = if builtins.pathExists ./kanshi/${hostname}.nix then
    import ./kanshi/${hostname}.nix { inherit lib pkgs; }
  else {
    profiles = { };
  };

in {
  services.kanshi = {
    enable = true;
    settings =
      lib.mapAttrsToList (name: profile: {
        profile = profile // {
          inherit name;
          # kanshi applies the profile, then runs exec. Re-power every output
          # so a head that came up DPMS/power-off (hotplugged while the session
          # was idle/locked) actually lights up: kanshi's modeset reports
          # success but never commits a mode to a powered-off CRTC, leaving the
          # panel dark at current_mode 0x0. Idempotent for already-on heads (no
          # modeset, no flicker) and orthogonal to enable/disable, so it won't
          # re-enable an output a profile set to `status disable`. This is the
          # automatic-path counterpart to the same `output * power on` in the
          # rofi-kanshi manual switcher (pkgs/scripts/rofi-kanshi).
          exec = (profile.exec or [ ]) ++ [
            "${pkgs.sway}/bin/swaymsg 'output * power on'"
          ];
        };
      })
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

  # Restart kanshi when its config changes. The HM module only sets
  # Restart=always (crash respawn), so without this a `nh os switch` that edits
  # a profile wouldn't apply until logout or a manual `systemctl --user restart
  # kanshi`. sd-switch restarts the unit when this trigger's store path changes.
  systemd.user.services.kanshi.Unit.X-Restart-Triggers =
    [ config.xdg.configFile."kanshi/config".source ];
}
