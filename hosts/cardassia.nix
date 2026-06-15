# NixOS config for work laptop (mordor's successor — ThinkPad P14s)
#
# Derived from hosts/mordor.nix. Differences from mordor:
#   - disko owns the disk (LUKS + btrfs + /persist + dormant @root-blank
#     snapshot for staged impermanence) → modules.disk-layout.enable, and
#     NO swapDevices here (the @swap subvolume provides it; zram backs up).
#   - tailscale joins the tailnet on first boot via a sops auth key.
#
# ⚠ CONFIRM ON ARRIVAL — items to revisit once the actual P14s is in hand
#   (search this file for "CONFIRM ON ARRIVAL"):
#     1. nixos-hardware module  (P14s, not T14s — variant Intel/AMD TBD)
#     2. kvm-intel vs kvm-amd + microcode  (in hardware/cardassia.nix)
#     3. evdi/DisplayLink dock overlay + WLR_EVDI_RENDER_DEVICE PCI path
#     4. TLP battery/CPU thresholds
#     5. nix.settings max-jobs/cores  (depends on the P14s core count)
{ config, lib, pkgs, inputs, hostname, username, ... }:

{
  networking.hostName = hostname;
  imports = [
    # ⚠ CONFIRM ON ARRIVAL (1): T14s carried over from mordor as the closest
    # stand-in so the flake evaluates today. Swap for the matching
    # lenovo-thinkpad-p14s-* module once the laptop arrives (check
    # https://github.com/NixOS/nixos-hardware for the exact gen/variant attr;
    # AMD and Intel have different ones).
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14s
    ../base.nix
    ../home.nix
    ../modules/nixos
    ../hardware/${hostname}.nix
  ];

  modules = {
    emacs = {
      enable = false;
      package = pkgs.emacs-unstable;
      defaultEditor = false;
    };

    bluetooth.enable = true;
    # GPT + LUKS + btrfs subvolumes incl. /persist and the dormant
    # @root-blank snapshot (modules/nixos/disk-layout.nix). Also provides
    # the swapfile, so no swapDevices block here (zram from base.nix backs
    # it up). The boot-time root wipe is NOT armed — impermanence is
    # adopted in stages (see cardassia-setup.md Phase F).
    disk-layout.enable = true;
    gc = {
      enable = true;
      method = "nh";
    };
    nfs.enable = true;
    openrazer.enable = true;
    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscale-auth-key.path;
    };
    touchegg.enable = true;

    # Greetd + tuigreet session picker (i3 + sway), same as mordor.
    # Deploy with `nh os boot` + reboot, NOT a live switch (see
    # modules/nixos/wayland-session.nix). Recovery: pick the previous
    # generation from systemd-boot.
    wayland.registerSession = true;
  };

  # tailscale auth key: host-scoped (NOT in base.nix's shared secrets list)
  # so betazed/mordor are unaffected. The secret must exist in
  # sops/secrets.yaml before cardassia activates (cardassia-setup.md
  # Phase B); tailscaled runs as root, so default root-owned 0400 is fine.
  sops.secrets.tailscale-auth-key = { };

  # This value determines the NixOS release with which your system is to be
  # compatible. Fresh install on 26.05 — never copy an older host's value.
  system.stateVersion = "26.05"; # Did you read the comment?

  # resolutions that aren't detected automatically so add them manually
  services.xserver = {
    monitorSection = ''
      Modeline "2560x1440"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
      Modeline "1920x1080"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
    '';
    deviceSection = ''
      Option "ModeValidation" "AllowNonEdidModes"
    '';
    resolutions = [
      {
        x = 2560;
        y = 1440;
      }
      {
        x = 3840;
        y = 2160;
      }
      {
        x = 1920;
        y = 1080;
      }
    ];
  };

  # ⚠ CONFIRM ON ARRIVAL (5): copied from mordor (4 cores / 8 threads). The
  # P14s may have a different core count — revisit so nix doesn't run more
  # parallel derivations than the machine can feed without OOMing.
  nix.settings = {
    max-jobs = 2;
    cores = 4;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # ⚠ CONFIRM ON ARRIVAL (4): thresholds copied from mordor; review against
  # the P14s battery/silicon.
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 20;

      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0 = 95;

    };
  };

  # services.fprintd.enable = true;
  # security.pam.services.login.fprintAuth = true;
  # security.pam.services.sudo.fprintAuth = true;
  # security.pam.services.i3lock.fprintAuth = true;
  # security.pam.services.polkit-1.fprintAuth = true;

  # security.polkit.extraConfig = ''
  #   polkit.addRule(function(action, subject) {
  #     if ((action.id == "net.reactivated.fprint.device.enroll") ||
  #         (action.id == "net.reactivated.fprint.device.verify") ||
  #         (action.id == "net.reactivated.fprint.device.delete")) {
  #       return polkit.Result.YES;
  #     }
  #   });
  # '';

  # Ensure users in these groups can access the fingerprint reader
  users.groups.plugdev.members = [ config.users.users.${username}.name ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment.systemPackages = [ pkgs.android-studio pkgs.polkit_gnome ];

  programs.nix-ld.enable = true;

  # ⚠ CONFIRM ON ARRIVAL (3): DisplayLink/evdi dock support, carried over
  # from mordor verbatim. Keep this block ONLY if cardassia uses the same
  # DisplayLink dock. Two caveats:
  #   - The patches pin wlroots_0_19 + scenefx (26.05, same as mordor) so
  #     they apply identically and the closure pre-builds fine.
  #   - WLR_EVDI_RENDER_DEVICE below points at the INTEL iGPU's fixed PCI
  #     address (0000:00:02.0). On an AMD P14s the iGPU PCI address differs
  #     — re-derive with `ls -l /dev/dri/by-path/`. If the dock is native
  #     DP-alt-mode/USB-C (not DisplayLink), drop this overlay entirely.
  # See hosts/mordor.nix for the full history of why these patches exist.
  nixpkgs.overlays = [
    (final: prev: {
      wlroots_0_19 = prev.wlroots_0_19.overrideAttrs (old: {
        patches = (old.patches or [ ])
          ++ [ ../patches/wlroots-evdi-render-device-v3.patch ];
      });
      scenefx = prev.scenefx.overrideAttrs (old: {
        patches = (old.patches or [ ])
          ++ [ ../patches/scenefx-evdi-render-device-v3.patch ];
      });
    })
  ];
  environment.variables.WLR_EVDI_RENDER_DEVICE =
    "/dev/dri/by-path/pci-0000:00:02.0-card";
}
