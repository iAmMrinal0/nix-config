{ config, lib, username, ... }:

with lib;

let
  cfg = config.modules.nfs;
  userHome = "/home/${username}";
in {
  options.modules.nfs = {
    enable = mkEnableOption "Enable NFS client and atlas media mount at ~/tnas";
  };

  config = mkIf cfg.enable {
    # Lazy-mounted via systemd automount so an unreachable server
    # (e.g. laptop off home network) doesn't block boot or hang shells.
    boot.supportedFilesystems = [ "nfs" ];
    services.rpcbind.enable = true;

    fileSystems."${userHome}/tnas" = {
      device = "atlas:/mnt/data/media";
      fsType = "nfs";
      options = [
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "x-systemd.mount-timeout=10s"
        "_netdev"
        "soft"
        "timeo=50"
        # Hide from GVFS / Thunar / udisks2. Without this, Thunar sees the
        # fstab entry and tries to mount it itself by g_spawn-ing `mount`,
        # which fails because the sway-launched session's PATH doesn't
        # include /run/wrappers/bin where NixOS keeps the setuid mount.
        # systemd-automount handles the actual mounting transparently on
        # first access (cd / ls / stat), so Thunar doesn't need to.
        "x-gvfs-hide"
      ];
    };
  };
}
