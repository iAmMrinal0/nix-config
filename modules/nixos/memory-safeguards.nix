{ config, lib, ... }:

with lib;

let cfg = config.modules.memorySafeguards;
in {
  options.modules.memorySafeguards = {
    enable = mkEnableOption "Enable memory pressure safeguards (systemd-oomd + vm sysctls)";

    pressureDuration = mkOption {
      type = types.str;
      default = "10s";
      description = ''
        How long sustained memory pressure must persist before
        systemd-oomd kills a cgroup. Shorter = more aggressive.
      '';
    };

    pressureLimit = mkOption {
      type = types.str;
      default = "50%";
      description = ''
        Memory pressure (PSI) above which systemd-oomd kills the worst
        offender in a monitored slice. The nixpkgs oomd module defaults
        this to 80%, which in practice never fires before the kernel
        OOM killer does.
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

    # The nixpkgs oomd module only wires up pressure-based kills and
    # leaves ManagedOOMSwap at "auto" everywhere, so nothing reacts
    # when swap fills up — the kernel OOM killer only fires at total
    # exhaustion, after minutes of thrashing (swap was 0 bytes free at
    # the May 2026 kernel OOM kills). Watch swap from the root slice
    # (Fedora's default) so the biggest swap consumer is killed once
    # usage crosses oomd's SwapUsedLimit (90%).
    systemd.slices."-".sliceConfig.ManagedOOMSwap = "kill";

    # Override the per-slice mkDefault "80%" pressure limit set by the
    # oomd module; 80% sustained pressure effectively never triggers
    # before the kernel OOM killer does.
    systemd.slices."-".sliceConfig.ManagedOOMMemoryPressureLimit = cfg.pressureLimit;
    systemd.slices."system".sliceConfig.ManagedOOMMemoryPressureLimit = cfg.pressureLimit;
    systemd.slices."user".sliceConfig.ManagedOOMMemoryPressureLimit = cfg.pressureLimit;

    boot.kernel.sysctl = {
      "vm.swappiness" = mkDefault cfg.swappiness;
    };
  };
}
