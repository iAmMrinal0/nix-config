{ config, lib, ... }:

with lib;

let cfg = config.modules.disk-layout;
in {
  options.modules.disk-layout = {
    enable = mkEnableOption "Declarative disk layout (disko): GPT + LUKS + btrfs subvolumes";

    device = mkOption {
      type = types.str;
      default = "/dev/nvme0n1";
      description = "Disk to format and manage";
    };

    swapSize = mkOption {
      type = types.str;
      default = "4G";
      description = "Size of the btrfs swapfile (nodatacow handled by disko)";
    };
  };

  config = mkIf cfg.enable {
    disko.devices.disk.main = {
      type = "disk";
      device = cfg.device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings = { allowDiscards = true; };
              # Read at format time only; create it before running disko:
              #   echo -n "<passphrase>" > /tmp/disk.key
              passwordFile = "/tmp/disk.key";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                # Read-only blank snapshot of the empty root subvolume.
                # Unused until impermanence is enabled, at which point an
                # initrd service restores @root from it on every boot.
                postCreateHook = ''
                  MNTPOINT=$(mktemp -d)
                  mount /dev/mapper/cryptroot "$MNTPOINT" -o subvolid=5
                  trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                  btrfs subvolume snapshot -r "$MNTPOINT/@root" "$MNTPOINT/@root-blank"
                '';
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  # State that must survive an (eventual) ephemeral root.
                  # Until impermanence is enabled this is just an empty,
                  # mounted subvolume.
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@swap" = {
                    mountpoint = "/.swap";
                    swap.swapfile.size = cfg.swapSize;
                  };
                };
              };
            };
          };
        };
      };
    };

    # Mounted in the initrd so early consumers (sops-nix host key, once
    # impermanence moves /etc/ssh here) can rely on it.
    fileSystems."/persist".neededForBoot = true;
  };
}
