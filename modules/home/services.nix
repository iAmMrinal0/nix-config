{ config, pkgs, lib, osConfig, ... }:

let
  # Wayland session hosts use gammastep (Wayland-native); X11 hosts keep
  # redshift. Read straight from NixOS config so the choice is gated on
  # the same flag that flips the display manager.
  isWayland = osConfig.modules.wayland.registerSession or false;
in {
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

  # X11 screen-locker stack (xss-lock + i3lock-custom). Only enabled
  # on X11 hosts — under sway, swayidle handles idle timeouts,
  # before-sleep, and `loginctl lock-session` events directly via
  # swaylock (see modules/home-manager/sway/config.nix swayidleCmd).
  # Running both concurrently caused a re-lock cascade: every logind
  # lock event fired both swayidle's swaylock AND xss-lock's
  # i3lock-custom, layering them on top of each other so each unlock
  # only peeled back one layer.
  services.screen-locker = lib.mkIf (!isWayland) {
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

  services.redshift = lib.mkIf (!isWayland) {
    enable = true;
    tray = true;
    provider = "geoclue2";
    temperature = {
      day = 5600;
      night = 3000;
    };
  };

  # Wayland equivalent of redshift. Same temperatures + geoclue2 provider so
  # behaviour matches across hosts. Tray indicator is published as an SNI
  # item picked up by waybar's tray module.
  services.gammastep = lib.mkIf isWayland {
    enable = true;
    tray = true;
    provider = "geoclue2";
    temperature = {
      day = 5600;
      night = 3000;
    };
  };

  # Anti-race override: gammastep's systemd user unit binds to the graphical
  # session target and races sway's WAYLAND_DISPLAY env import the same way
  # waybar/kanshi/blueman/kdeconnect did. Disable the auto-start; sway exec
  # launches gammastep-indicator in sway's process env (see sway/config.nix).
  systemd.user.services.gammastep.Install.WantedBy = lib.mkIf isWayland (lib.mkForce [ ]);
}
