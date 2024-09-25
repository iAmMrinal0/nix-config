# NixOS config for personal laptop
{ config, pkgs, ... }:

{
  networking.hostName = "mordor";
  # powerManagement.resumeCommands =
  #  "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";
}
