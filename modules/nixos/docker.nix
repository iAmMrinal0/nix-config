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

      # Keep containers running across daemon restarts (containerd shims
      # hold them; the new daemon re-attaches). Was the implicit default
      # via the stateVersion < 24.11 legacy gate; pinned explicitly when
      # stateVersion moved to 26.05 so rebuilds that bump docker don't
      # kill running work containers. Incompatible with swarm (unused).
      virtualisation.docker.daemon.settings.live-restore = true;

      environment.systemPackages =
        mkIf cfg.installCompose [ pkgs.docker-compose ];
    })

    (mkIf (cfg.enable && cfg.addUserToGroup) {
      users.users.${username}.extraGroups = [ "docker" ];
    })
  ];
}
