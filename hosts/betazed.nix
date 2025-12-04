# NixOS config for personal laptop
{ config, pkgs, inputs, hostname, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
    ../base.nix
    ../modules/nixos
    ../home.nix
    ../hardware/${hostname}.nix
    ../modules/nixos/nvidia.nix
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

  networking.hostName = hostname;
  powerManagement.resumeCommands =
    "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";

  # keep this in sync with swapDevices in hardware/${hostname}.nix  
  boot.resumeDevice = "/dev/disk/by-uuid/34266fca-fc14-434a-bc58-fb50a883256b";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "24.05"; # Did you read the comment?

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

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    acceleration = "cuda";
  };

  environment.systemPackages = [ pkgs.rpi-imager pkgs.ansible ];

}
