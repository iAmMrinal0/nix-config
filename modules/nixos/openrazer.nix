{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.openrazer;
in {
  options.modules.openrazer = {
    enable = mkEnableOption "Enable OpenRazer drivers and software";

    addUser = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add the main user to openrazer group";
    };

    installRazergenie = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the razergenie package";
    };
  };

  config = mkIf cfg.enable {
    hardware.openrazer = {
      enable = true;
      users = mkIf cfg.addUser [ config.users.users.iammrinal0.name ];
    };

    environment.systemPackages = mkIf cfg.installRazergenie [ pkgs.razergenie ];
  };
}
