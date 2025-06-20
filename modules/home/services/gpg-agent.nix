{ config, pkgs, lib, ... }:

with lib;

let cfg = config.personal.gpg-agent;
in {
  options.personal.gpg-agent = {
    enable = mkEnableOption "GPG agent configuration";

    pinentryFlavor = mkOption {
      type = types.enum [ "gtk2" "gnome3" "qt" "curses" "tty" "emacs" ];
      default = "qt";
      description = "Which pinentry interface to use";
    };

    defaultCacheTtl = mkOption {
      type = types.int;
      default = 1800;
      description = "Default cache TTL in seconds";
    };

    maxCacheTtl = mkOption {
      type = types.int;
      default = 7200;
      description = "Maximum cache TTL in seconds";
    };

    enableSshSupport = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use GPG agent for SSH";
    };
  };

  config = mkIf cfg.enable {
    services.gpg-agent = {
      enable = true;
      pinentry.package = if cfg.pinentryFlavor == "gtk2" then
        pkgs.pinentry-gtk2
      else if cfg.pinentryFlavor == "gnome3" then
        pkgs.pinentry-gnome3
      else if cfg.pinentryFlavor == "qt" then
        pkgs.pinentry-qt
      else if cfg.pinentryFlavor == "curses" then
        pkgs.pinentry-curses
      else if cfg.pinentryFlavor == "tty" then
        pkgs.pinentry-tty
      else if cfg.pinentryFlavor == "emacs" then
        pkgs.pinentry-emacs
      else
        pkgs.pinentry;
      defaultCacheTtl = cfg.defaultCacheTtl;
      maxCacheTtl = cfg.maxCacheTtl;
      enableSshSupport = cfg.enableSshSupport;
    };
  };
}
