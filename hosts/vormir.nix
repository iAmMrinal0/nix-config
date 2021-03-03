# NixOS config for ThinkPad X1 Carbon
{ config, lib, pkgs, ... }:

{
  imports =
    [ ../hardware/carbon.nix
      ../base.nix
    ];

  networking.hostName = "vormir"; # Define your hostname.

  services.xserver.resolutions = [ { x = 1920; y = 1080; } ];

  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [ vaapiIntel ];
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  environment.variables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = lib.mkDefault "1";
  };

  hardware.video.hidpi.enable = true;
}
