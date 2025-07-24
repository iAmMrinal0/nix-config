# NixOS config for work laptop
{ config, lib, pkgs, inputs, hostname, ... }:

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
    openrazer.enable = true;
    touchegg.enable = true;
  };

  # powerManagement.resumeCommands =
  #  "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "24.05"; # Did you read the comment?

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

  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.i3lock.fprintAuth = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "net.reactivated.fprint.device.enroll") ||
          (action.id == "net.reactivated.fprint.device.verify") ||
          (action.id == "net.reactivated.fprint.device.delete")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Ensure users in these groups can access the fingerprint reader
  users.groups.plugdev.members = [ config.users.users.iammrinal0.name ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
