# NixOS config for personal laptop
{ config, pkgs, ... }:

{
  imports = [ ../hardware/betazed.nix ../base.nix ];

  networking.hostName = "betazed";

  powerManagement.resumeCommands =
    "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";

}
