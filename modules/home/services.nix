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
    xautolock = {
      extraOptions = [
        "-corners" "---+" "-cornerdelay" "1"
        "-notify" "10"
        "-notifier"
        "'${pkgs.libnotify}/bin/notify-send \"⚠️ Locking in 10 seconds...\"'"
      ];
    };
  };
}
