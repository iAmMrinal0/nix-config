{ config, pkgs, lib, ... }:

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

  services.gnome-keyring.enable = true;

  services.screen-locker = {
    enable = true;
    inactiveInterval = 5;
    lockCmd = "${pkgs.scripts.i3lock-custom}/bin/i3lock-custom";
    xss-lock = {
      # This ensures the screen locks before suspend/hibernate
      extraOptions = [ "--transfer-sleep-lock" ];
    };
    xautolock = {
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
        "-notify"
        "60"
        "-notifier"
        "'${pkgs.libnotify}/bin/notify-send \"⚠️ Locking soon...\"'"
      ];
    };
  };

  services.mpris-proxy.enable = true;
}
