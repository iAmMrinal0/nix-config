{ config, lib, ... }:

with lib;

let cfg = config.modules.memorySafeguards;
in {
  options.modules.memorySafeguards = {
    enable = mkEnableOption "Enable memory pressure safeguards (systemd-oomd + vm sysctls)";

    pressureDuration = mkOption {
      type = types.str;
      default = "20s";
      description = ''
        How long sustained memory pressure must persist before
        systemd-oomd kills a cgroup. Shorter = more aggressive.
      '';
    };

    swappiness = mkOption {
      type = types.int;
      default = 150;
      description = ''
        vm.swappiness. Values >100 favour compressing anon pages to
        zram over evicting file cache — appropriate when zramSwap
        is enabled.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
      settings.OOM = {
        DefaultMemoryPressureDurationSec = cfg.pressureDuration;
      };
    };

    boot.kernel.sysctl = {
      "vm.swappiness" = mkDefault cfg.swappiness;
    };
  };
}
