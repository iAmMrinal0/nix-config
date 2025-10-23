{ pkgs, lib, ... }:

let
  mkRcloneMountService = { name, description, remote, mountPath
    , cacheDir ? "/home/iammrinal0/.cache/rclone/${name}" }: {
      "rclone-${name}-mount" = {
        Unit = {
          Description = description;
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Install = { WantedBy = [ "default.target" ]; };

        Service = {
          Type = "simple";

          # Ensure mount path and cache directory exist
          ExecStartPre = ''
            /run/current-system/sw/bin/mkdir -p ${mountPath}
            /run/current-system/sw/bin/mkdir -p ${cacheDir}
          '';

          ExecStart = ''
            ${pkgs.rclone}/bin/rclone mount \
              --vfs-cache-mode full \
              --vfs-cache-max-age 24h \
              --vfs-cache-max-size 10G \
              --cache-dir ${cacheDir} \
              --allow-non-empty \
              ${remote}: ${mountPath}
          '';

          ExecStop = "/run/current-system/sw/bin/fusermount -u ${mountPath}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = [ "PATH=/run/wrappers/bin/:$PATH" ];
        };
      };
    };
in {
  systemd.user = {
    startServices = true;
    services = lib.mkMerge [
      (mkRcloneMountService {
        name = "gdrive";
        description = "Google Drive mount";
        remote = "gdrive";
        mountPath = "/home/iammrinal0/gdrive";
      })

      (mkRcloneMountService {
        name = "tdrive";
        description = "WebDAV tailscale taildrive mount";
        remote = "tdrive";
        mountPath = "/home/iammrinal0/tdrive";
      })
    ];
  };
}
