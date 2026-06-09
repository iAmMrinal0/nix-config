{ config, pkgs, lib, osConfig, ... }:

{
  imports = [
    # Security-related services
    ./services/gpg-agent.nix

    # System services group
    ./services/system-services.nix

  ];

  personal = {
    gpg-agent = {
      enable = true;
      pinentryFlavor = "qt";
      defaultCacheTtl = 3600; # 1 hour
      maxCacheTtl = 86400; # 24 hours
      enableSshSupport = false;
    };
  };

  # X11 screen-locker stack (xss-lock + i3lock-custom). Installed
  # unconditionally now that one generation serves both i3 and sway, but
  # its systemd unit is launched ONLY under i3 (see the WantedBy override
  # below + the i3 startup entry in modules/home-manager/i3/config.nix).
  # Under sway, swayidle handles idle timeouts, before-sleep, and
  # `loginctl lock-session` events directly via swaylock (see
  # modules/home-manager/sway/config.nix swayidleCmd). The two are
  # mutually exclusive per boot (you pick one WM), so the old re-lock
  # cascade — every logind lock event firing both swayidle's swaylock AND
  # xss-lock's i3lock-custom — can't recur. We still gate xss-lock to i3
  # because it needs an X server (it would just fail to start under sway).
  services.screen-locker = {
    enable = true;
    inactiveInterval = 5;
    lockCmd = "${pkgs.my.scripts.i3lock-custom}/bin/i3lock-custom";
    xss-lock = {
      # This ensures the screen locks before suspend/hibernate
      extraOptions = [ "--transfer-sleep-lock" ];
    };
    xautolock = {
      enable = false;
      extraOptions = [
        # lock on top left instantly
        # don't lock when on top right or bottom left
        # do nothing when on bottom right (default locking behavior)
        "-corners"
        "+--0"
        # lock a second after when on top left
        "-cornerdelay"
        "1"
        # relock after 30 seconds of unlocking if mouse still on top left
        "-cornerredelay"
        "30"
        "-resetsaver"
        "-notify"
        "60"
        "-notifier"
        "'${pkgs.libnotify}/bin/notify-send \"⚠️ Locking soon...\"'"
      ];
    };
  };

  services.mpris-proxy.enable = true;

  # X11 color-temperature daemon. Installed unconditionally; launched only
  # under i3 (gammastep covers sway). Autostart disabled below because its
  # unit is WantedBy graphical-session.target, which sway ALSO activates
  # (sway-session.target bindsTo it) — leaving autostart on would start
  # redshift under sway too, where it fails (no X) and would double up with
  # gammastep. i3 starts it explicitly from its startup list.
  services.redshift = {
    enable = true;
    tray = true;
    provider = "geoclue2";
    temperature = {
      day = 5600;
      night = 3000;
    };
  };

  # Wayland equivalent of redshift. Same temperatures + geoclue2 provider so
  # behaviour matches across stacks. Tray indicator is published as an SNI
  # item picked up by waybar's tray module. Installed unconditionally;
  # launched only under sway (see WantedBy override + sway/config.nix exec).
  services.gammastep = {
    enable = true;
    tray = true;
    provider = "geoclue2";
    temperature = {
      day = 5600;
      night = 3000;
    };
  };

  # Disable systemd autostart for the per-WM color daemons and the X11
  # locker; each is launched by its own WM's startup instead. This is the
  # same anti-race pattern used for waybar/kanshi/blueman/kdeconnect:
  #   - gammastep: races sway's WAYLAND_DISPLAY import at session start, so
  #     sway exec's gammastep-indicator in sway's process env.
  #   - redshift + xss-lock: X11-only; i3 starts them from its startup list
  #     (modules/home-manager/i3/config.nix) so they never fire under sway,
  #     where graphical-session.target is active but no X server exists.
  #   - picom: X11 compositor; same story — it was WantedBy
  #     graphical-session.target, so it leaked into sway (a useless X
  #     compositor under wlroots). i3 starts it from its startup list instead.
  systemd.user.services.gammastep.Install.WantedBy = lib.mkForce [ ];
  systemd.user.services.redshift.Install.WantedBy = lib.mkForce [ ];
  systemd.user.services.xss-lock.Install.WantedBy = lib.mkForce [ ];
  systemd.user.services.picom.Install.WantedBy = lib.mkForce [ ];
}
