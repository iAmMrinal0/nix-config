{ config, lib, pkgs, username, ... }:

with lib;

let cfg = config.modules.docker;
in {
  options.modules.docker = {
    enable = mkEnableOption "Enable Docker virtualization";

    addUserToGroup = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add the user to the docker group";
    };

    installCompose = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install docker-compose";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      virtualisation.docker.enable = true;

      environment.systemPackages =
        mkIf cfg.installCompose [ pkgs.docker-compose ];
    })

    (mkIf (cfg.enable && cfg.addUserToGroup) {
      users.users.${username}.extraGroups = [ "docker" ];
    })
  ];
}
