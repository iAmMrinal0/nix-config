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

      # Route container logs to the bounded "local" driver instead of
      # journald. The kronor dev stack (pgbouncer x2, nginx, ...) was
      # logging ~120k lines/day straight into the systemd journal, about
      # half its total volume. The local driver keeps per-container logs
      # under /var/lib/docker with rotation, out of journald entirely.
      # NOTE: existing containers keep their old driver — recreate them
      # (docker compose down && up, or docker rm/run) to pick this up.
      virtualisation.docker.daemon.settings.log-driver = "local";
      virtualisation.docker.daemon.settings.log-opts = {
        max-size = "10m";
        max-file = "3";
      };

      environment.systemPackages =
        mkIf cfg.installCompose [ pkgs.docker-compose ];
    })

    (mkIf (cfg.enable && cfg.addUserToGroup) {
      users.users.${username}.extraGroups = [ "docker" ];
    })
  ];
}
