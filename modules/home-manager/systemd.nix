{ pkgs, ... }: {
  systemd = {
    user = {
      startServices = true;
      services = {
        mpris-proxy = {
          Unit.Description = "Mpris proxy";
          Unit.After = [ "network.target" "sound.target" ];
          Service.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
          Install.WantedBy = [ "default.target" ];
        };
        rclone-gdrive-mount = {
          Unit = {
            Description = "Service that connects to Google Drive";
            After = [ "default.target" ];
            # Requires = [ "network.target" ];
          };
          Install = { WantedBy = [ "default.target" ]; };

          Service = let gdriveDir = "/home/iammrinal0/gdrive";
          in {
            Type = "simple";
            ExecStart =
              "${pkgs.rclone}/bin/rclone mount --vfs-cache-mode full gdrive: ${gdriveDir}";
            ExecStop = "/run/current-system/sw/bin/fusermount -u ${gdriveDir}";
            Restart = "on-failure";
            RestartSec = "10s";
            Environment = [ "PATH=/run/wrappers/bin/:$PATH" ];

          };
        };

      };
    };
  };
}
