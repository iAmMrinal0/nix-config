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

    zramPercent = mkOption {
      type = types.int;
      default = 50;
      description = ''
        zramSwap.memoryPercent. nixpkgs defaults this to 50, which is
        sized for machines whose ONLY swap is zram. zram lives in RAM,
        and oomd counts it toward SwapUsedLimit, so on a host that also
        has an on-disk swap device a 50% zram both halves the RAM
        available to real processes under pressure and inflates the swap
        total that oomd measures against. Lower it on hosts with a real
        swap partition; leave it at 50 where zram is the only swap.
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

    # Keep the graphical session off oomd's candidate list. The swap kill
    # above picks whichever monitored cgroup holds the most swap, and on a
    # desktop that is reliably session-N.scope — the logind scope that
    # holds the compositor itself. The result was the worst possible
    # outcome: instead of reaping the process that ate the memory, oomd
    # killed sway and every window with it, dropping the user back to the
    # greetd greeter (betazed did this seven times between 2026-06-19 and
    # 2026-09-01).
    #
    # "avoid" deprioritises the scope rather than exempting it, so oomd
    # walks past it to the real hogs — the app scopes under
    # user@.service (browser, editor, tmux servers, the rclone mounts)
    # — but can still fall back to it as a last resort rather than
    # deadlocking into a kernel OOM freeze.
    #
    # logind names these scopes session-1.scope, session-2.scope, …, so
    # there is no single unit to attach this to. systemd resolves
    # drop-ins for dashed unit names by repeatedly truncating after each
    # dash (systemd.unit(5)), so session-N.scope picks up
    # session-.scope.d/ — which is what overrideStrategy = "asDropin"
    # generates here.
    systemd.units."session-.scope" = {
      overrideStrategy = "asDropin";
      text = ''
        [Scope]
        ManagedOOMPreference=avoid
      '';
    };

    zramSwap.memoryPercent = mkDefault cfg.zramPercent;

    boot.kernel.sysctl = {
      "vm.swappiness" = mkDefault cfg.swappiness;
    };
  };
}
