{ config, lib, ... }:

with lib;

let cfg = config.modules.boot;
in {
  options.modules.boot = {
    enable = mkEnableOption "Enable boot configuration";

    loader = {
      systemd-boot.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable systemd-boot";
      };

      efi.canTouchEfiVariables = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the EFI variables can be modified";
      };
    };

    tmp = {
      useTmpfs = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use tmpfs for /tmp";
      };

      cleanOnBoot = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to clean /tmp on boot";
      };
    };

    plymouth.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Plymouth boot splash";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      loader = {
        systemd-boot.enable = cfg.loader.systemd-boot.enable;
        efi.canTouchEfiVariables = cfg.loader.efi.canTouchEfiVariables;
      };

      tmp = {
        useTmpfs = cfg.tmp.useTmpfs;
        cleanOnBoot = cfg.tmp.cleanOnBoot;
      };

      plymouth.enable = cfg.plymouth.enable;
    };
  };
}
