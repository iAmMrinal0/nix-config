# NixOS config for work laptop
{ config, pkgs, ... }:

{
  networking.hostName = "mordor";
  imports = [ ../modules/adb.nix ../base.nix ];
  # powerManagement.resumeCommands =
  #  "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "24.05"; # Did you read the comment?

}
