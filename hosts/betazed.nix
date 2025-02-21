# NixOS config for personal laptop
{ config, pkgs, ... }:

{
  imports = [
    ../base.nix
    ../modules/nixos/vscode.nix
    ../modules/nixos/xserver.nix
    ../home.nix ];
  networking.hostName = "betazed";
  powerManagement.resumeCommands =
    "${pkgs.kmod}/bin/rmmod atkbd; ${pkgs.kmod}/bin/modprobe atkbd reset=1";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "24.05"; # Did you read the comment?
}
