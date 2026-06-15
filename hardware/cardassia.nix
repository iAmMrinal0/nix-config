# STAND-IN until the laptop arrives: kernel-module guesses copied from
# mordor so the cardassia flake output evaluates (VM rehearsal,
# pre-building the closure). Replace on install day with the output of
# `nixos-generate-config --root /mnt --no-filesystems` — filesystems are
# declared by disko (modules/nixos/disk-layout.nix), so the real file
# must be generated WITHOUT them too.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
