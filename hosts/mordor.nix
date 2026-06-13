# NixOS config for work laptop
{ config, lib, pkgs, inputs, hostname, username, ... }:

{
  networking.hostName = hostname;
  imports = [
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
    gc = {
      enable = true;
      method = "nh";
    };
    nfs.enable = true;
    openrazer.enable = true;
    touchegg.enable = true;

    # Phase 3 cutover (2026-06-11): greetd + tuigreet session picker with
    # both i3 and sway. Flipped after the dock gates passed — sway docked
    # + hotplug flicker-free at 75Hz (evdi v3 patches below). Deploy with
    # `nh os boot` + reboot, NOT a live switch (see
    # modules/nixos/wayland-session.nix).
    # Recovery: pick the previous lightdm+i3 generation from systemd-boot.
    wayland.registerSession = true;
  };

  # powerManagement.resumeCommands =
  #  "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
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

  # No swap partition on mordor; add a 4 GB swap file to back up zram and
  # widen the window for systemd-oomd to react before memory is exhausted.
  swapDevices = [{
    device = "/var/swapfile";
    size = 4 * 1024;
  }];

  # 4 cores / 8 threads: don't let nix run 8 parallel derivations each
  # entitled to every core — parallel GHC builds were a main driver of
  # the RAM+swap exhaustion behind various kernel OOM kills.
  nix.settings = {
    max-jobs = 2;
    cores = 4;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

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

  # DisplayLink/evdi under wlroots, second round (2026-06-11 office TTY
  # test): UNPATCHED sway 1.11/wlroots 0.19.3 detects and lights up both
  # dock Samsungs, but every damage-heavy update (scrolling, typing)
  # flickers windows out to the wallpaper — silent frame corruption, no
  # wlroots errors logged. This is the failure mode the prepared fallback
  # in MULTI_SESSION_HANDOFF.md Phase 4b covers: patch wlroots' DRM
  # backend with proper evdi support (NixOS wiki "Displaylink" page;
  # written against 0.17, wiki claims it applies through 0.19 — a build
  # failure here means the patch finally bit-rotted, see the handoff for
  # alternatives). swayfx-unwrapped takes wlroots_0_19 from the package
  # set, so this host-scoped overlay reaches it without touching betazed
  # (which would otherwise rebuild sway for hardware it doesn't have).
  # --unsupported-gpu is already baked into the sway wrappers
  # (modules/nixos/wayland-session.nix + the HM carve-out).
  #
  # v3 (2026-06-11): the wiki's DisplayLink_v2 patch only accepted literal
  # /dev/dri/card0..card9 values for WLR_EVDI_RENDER_DEVICE and silently
  # fell back to card0 on anything else — including the by-path symlink
  # below. card numbering is dynamic (evdi grabbed card0 this boot, i915
  # was card1), so "card0" meant evdi rendering on itself: EGL device
  # matching failed and the outputs landed on a corrupt software path
  # (flicker-to-wallpaper, cursor trails). The local v3 patch accepts any
  # absolute path; open() resolves symlinks, so by-path works.
  #
  # scenefx must carry the same patch: it vendors a copy of wlroots'
  # render/egl.c, and SwayFX's renderer is created through scenefx, so a
  # wlroots-only patch never reaches it (confirmed by the egl.c:506 error
  # in the sway log — that line number exists only in scenefx's copy).
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
  # The patched backend renders evdi outputs on the GPU named here (the
  # iGPU). by-path is used instead of cardN because evdi cards are created
  # dynamically at dock-time and can shuffle numbering; 0000:00:02.0 is
  # the Intel iGPU's fixed PCI address. Verify once with
  # `ls -l /dev/dri/by-path/` if rendering ends up on the wrong device.
  environment.variables.WLR_EVDI_RENDER_DEVICE =
    "/dev/dri/by-path/pci-0000:00:02.0-card";
}
