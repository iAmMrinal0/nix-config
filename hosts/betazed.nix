# NixOS config for personal laptop
{ config, pkgs, inputs, hostname, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
    ../base.nix
    ../modules/nixos
    ../home.nix
    ../hardware/${hostname}.nix
    # ../modules/nixos/nvidia.nix
  ];

  modules = {
    emacs = {
      enable = false;
      package = pkgs.emacs-unstable;
      defaultEditor = false;
    };

    evolution.enable = true;

    gc = {
      enable = true;
      method = "nh";
    };

    nfs.enable = true;

    smb.enable = true;

    gfn.enable = true;

    connectiq.enable = true;

    # Session toggle: true → sway+greetd (Wayland), false → i3+lightdm (X11).
    # Both stacks are kept fully configured in this repo (the sway home-
    # manager modules in modules/home-manager/sway/ and the i3 modules in
    # modules/home-manager/i3/ are imported unconditionally; they generate
    # config files but only one is actually used per session). Flip this
    # one flag and rebuild to switch.
    wayland.registerSession = true;
  };

  networking.hostName = hostname;
  powerManagement.resumeCommands =
    "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";

  # keep this in sync with swapDevices in hardware/${hostname}.nix
  boot.resumeDevice = "/dev/disk/by-uuid/34266fca-fc14-434a-bc58-fb50a883256b";

  # 16G RAM with an 8G on-disk swap partition (hardware/betazed.nix), so
  # zram doesn't have to carry swap on its own. At the nixpkgs default of
  # 50% it added another 8G of RAM-resident swap, giving a 16G swap total
  # on a 16G machine: oomd's SwapUsedLimit=90% then measures against a
  # figure half of which IS the memory it is trying to protect. Quartering
  # it leaves ~4G of zram in front of the disk partition.
  modules.memorySafeguards.zramPercent = 25;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "26.05"; # Did you read the comment?

  # services.fprintd.enable = true;

  ## enable fingerprint reader. disabled because this wasn't working in 25.05
  # security.pam.services.login.fprintAuth = true;
  # security.pam.services.sudo.fprintAuth = true;
  # security.pam.services.i3lock.fprintAuth = true;

  # security.polkit.extraConfig = ''
  #   polkit.addRule(function(action, subject) {
  #     if ((action.id == "net.reactivated.fprint.device.enroll") ||
  #         (action.id == "net.reactivated.fprint.device.verify") ||
  #         (action.id == "net.reactivated.fprint.device.delete")) {
  #       return polkit.Result.YES;
  #     }
  #   });
  # '';

  # # Ensure users in these groups can access the fingerprint reader
  # users.groups.plugdev.members = [ config.users.users.iammrinal0.name ];

  # services."06cb-009a-fingerprint-sensor" = {                                 
  #   enable = true;                                                            
  #   # backend = "python-validity";
  #   backend = "libfprint-tod";                                                
  #   calib-data-file = ./calib-data.bin;      
  # };
  ## end of fingerprint reader config

  environment.systemPackages = [
    pkgs.ansible
    pkgs.handbrake
    pkgs.lm_sensors
    pkgs.smartmontools
    pkgs.xdg-utils
  ];
}
