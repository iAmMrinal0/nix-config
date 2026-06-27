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

    # Mount OUTSIDE $HOME, then symlink ~/tnas -> /mnt/tnas below.
    #
    # Why not mount directly at ~/tnas: sandboxed apps that bind the whole
    # home read-write (notably the GeForce NOW Flatpak, --filesystem=home)
    # recursively bind $HOME. A live nfs4 submount nested in $HOME makes
    # bubblewrap fail to re-apply mount flags onto it and the sandbox dies:
    #   bwrap: Can't bind mount …/home/<user>: Unable to apply mount flags:
    #          remount "…/tnas": No such device
    # A symlink isn't a mountpoint, so the home bind just copies the link
    # and there's no submount under $HOME to choke on — GFN keeps full home
    # access. See modules/nixos/gfn.nix.
    fileSystems."/mnt/tnas" = {
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

    # ~/tnas stays as the user-facing path (GTK bookmark in gtk.nix points
    # here). `L+` replaces any existing dir/link, so a stale automount dir
    # left over from the old in-home mount is cleaned up on switch.
    systemd.tmpfiles.rules = [ "L+ ${userHome}/tnas - - - - /mnt/tnas" ];
  };
}
