{ config, lib, username, ... }:

with lib;

let
  cfg = config.modules.smb;
  userHome = "/home/${username}";
in {
  options.modules.smb = {
    enable = mkEnableOption "Enable CIFS client and atlas personal SMB mount at ~/private";
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "cifs" ];

    # username=/password= pair for //atlas/<user> in mount.cifs credentials
    # format. Kept at sops-nix defaults (root:root 0400): only mount.cifs
    # reads it, and that runs as root — no reason to join the user-readable
    # defaultPermissions list in base.nix.
    sops.secrets.atlas-smb-credentials = { };

    # Same shape as the NFS media mount (nfs.nix): mount OUTSIDE $HOME and
    # symlink in — see there for the bubblewrap/sandbox rationale — lazily
    # via systemd automount so an unreachable atlas (laptop off the home
    # network) doesn't block boot or hang shells, and x-gvfs-hide so Thunar
    # treats it as a plain path instead of trying to mount it itself. The
    # kernel mounts with the credentials file above, so nothing ever prompts
    # for the SMB password.
    fileSystems."/mnt/atlas" = {
      device = "//atlas/${username}";
      fsType = "cifs";
      options = [
        "credentials=${config.sops.secrets.atlas-smb-credentials.path}"
        # CIFS has no uid mapping: without these, files appear root-owned.
        # Personal share, so keep it private from other local users too.
        "uid=${username}"
        "gid=users"
        "dir_mode=0700"
        "file_mode=0600"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "x-systemd.mount-timeout=10s"
        "_netdev"
        "soft"
        "x-gvfs-hide"
      ];
    };

    # ~/private is the user-facing path (GTK bookmark in gtk.nix points
    # here) — named for what the share is (the private personal dataset,
    # invisible to other NAS users), not the machine; /mnt/atlas keeps the
    # machine name like /mnt/tnas does.
    systemd.tmpfiles.rules = [ "L+ ${userHome}/private - - - - /mnt/atlas" ];
  };
}
