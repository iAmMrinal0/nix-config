{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.displayManager;
in {
  options.modules.displayManager = {
    enable = mkEnableOption "Enable display manager configuration";

    defaultSession = mkOption {
      type = types.str;
      default = "none+i3";
      description = "Default desktop session";
    };

    autoLogin = {
      enable = mkOption {
        type = types.bool;
        # for some reason the Login keyring doesn't work if autoLogin is enabled
        default = false;
        description = "Whether to enable auto login.";
      };

      user = mkOption {
        type = types.str;
        default = config.users.users.iammrinal0.name;
        description = "The user to auto login";
      };
    };
  };

  config = mkIf cfg.enable {
    services.displayManager = {
      defaultSession = cfg.defaultSession;
      autoLogin = mkIf cfg.autoLogin.enable {
        enable = true;
        user = cfg.autoLogin.user;
      };
    };
  };
}
