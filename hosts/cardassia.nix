# NixOS config for work laptop (mordor's successor — ThinkPad P14s Gen 6,
# Intel Core Ultra 9 285H, 16 cores / 64 GB).
#
# Derived from hosts/mordor.nix. Differences from mordor:
#   - disko owns the disk (LUKS + btrfs + /persist + dormant @root-blank
#     snapshot for staged impermanence) → modules.disk-layout.enable, and
#     NO swapDevices here (the @swap subvolume provides it; zram backs up).
{ config, lib, pkgs, inputs, hostname, username, ... }:

{
  networking.hostName = hostname;
  imports = [
    # nixos-hardware has no lenovo-thinkpad-p14s-intel-gen6 module (Intel
    # stops at gen5; only AMD has gen6), and the gen5 module adds nothing
    # beyond these generic profiles on a modern kernel — so use the common-*
    # set directly.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-ssd
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
    # adopted in stages.
    disk-layout.enable = true;
    gc = {
      enable = true;
      method = "nh";
    };
    # GeForce NOW at the native panel res — the Arc iGPU handles it (unlike
    # mordor's UHD 620, which is why the launcher defaults to 1080p).
    gfn = {
      enable = true;
      width = 2560;
      height = 1600;
    };
    nfs.enable = true;
    openrazer.enable = true;
    tailscale.enable = true;
    touchegg.enable = true;

    # Greetd + tuigreet session picker (i3 + sway), same as mordor.
    # Deploy with `nh os boot` + reboot, NOT a live switch (see
    # modules/nixos/wayland-session.nix). Recovery: pick the previous
    # generation from systemd-boot.
    wayland.registerSession = true;
  };

  # Boot-speed trims (see `systemd-analyze`):
  #   - systemd-boot timeout 1s (was 5s); hold Space at boot to reach the menu.
  #   - Skip the network-online wait (~7s): nothing here needs it — the only NFS
  #     mount is automount (noauto + x-systemd.automount). NM still connects in
  #     the background.
  # Bigger remaining costs (firmware POST, LUKS unlock) are BIOS/disk, not here.
  boot.loader.timeout = 1;
  systemd.services.NetworkManager-wait-online.enable = false;

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

  # Internal speaker fix (P14s Gen 6 / sof-hda-dsp). The card has two mutually
  # exclusive UCM HiFi profiles sharing one analog PCM — one with Headphones
  # (priority 10300), one with Speaker (10200). With HDMI present WirePlumber
  # always picks the higher-priority Headphones profile, so the Speaker sink
  # never appears. Pin the Speaker profile; it also has Mic1+Mic2 so the digital
  # mic still works. Upstream bug: alsa-ucm-conf#720, pipewire#4976.
  # Trade-off: no automatic wired-headphone-jack switching (switch the profile
  # by hand; Bluetooth is a separate card, unaffected).
  services.pipewire.wireplumber.extraConfig."52-cardassia-speaker-profile" = {
    "monitor.alsa.rules" = [
      {
        matches = [{ "device.name" = "~alsa_card.*skl_hda_dsp_generic"; }];
        actions.update-props = {
          "device.profile" = "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)";
        };
      }
    ];
  };

  # Keep Bluetooth headsets (e.g. WH-1000XM3) in A2DP/LDAC: don't auto-switch to
  # the HSP/HFP headset profile when an app opens a mic — voice capture falls
  # back to the laptop mic instead.
  services.pipewire.wireplumber.extraConfig."53-cardassia-bluetooth" = {
    "wireplumber.settings" = {
      "bluetooth.autoswitch-to-headset-profile" = false;
    };
  };

  # No nix.settings override: on 16 cores / 64 GB the defaults (max-jobs =
  # "auto", cores = 0) already use everything. mordor caps these to avoid OOM
  # on its 4 cores; cardassia doesn't need to.

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # Battery charge thresholds + CPU perf policy (BAT0).
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

  services.fprintd.enable = true;
  security.pam.services = {
    sudo.fprintAuth = true;
    swaylock.fprintAuth = true;
    i3lock.fprintAuth = true;
    polkit-1.fprintAuth = true;
  };

  # plugdev: fingerprint reader access (also used by openrazer).
  users.groups.plugdev.members = [ config.users.users.${username}.name ];

  # Mic-mute LED (P14s `platform::micmute`). Detach the kernel `audio-micmute`
  # trigger — it binds the LED to a hardware capture-switch mute, but PipeWire
  # mutes in software and never flips that, so the trigger held the LED dark and
  # overrode manual writes. trigger=none + group-write on `brightness` let the
  # shared mic-mute-toggle keybind drive it. Host-local because this is the only
  # host with this LED node; the script no-ops the LED where it's absent.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{trigger}="none", RUN+="${pkgs.coreutils}/bin/chgrp audio /sys/class/leds/platform::micmute/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/platform::micmute/brightness"
  '';

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment.systemPackages = [ pkgs.android-studio pkgs.polkit_gnome ];

  programs.nix-ld.enable = true;

  # DisplayLink/evdi dock support, carried over from mordor (cardassia uses a
  # DisplayLink dock at the office). WLR_EVDI_RENDER_DEVICE below points at the
  # Intel Arc iGPU at PCI 0000:00:02.0. The patches pin wlroots_0_19 + scenefx
  # to 26.05 so they apply cleanly.
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
