# NixOS config for ThinkPad X1 Carbon
{ config, lib, pkgs, ... }:

{
  imports =
    [ ../hardware/carbon.nix
      ../base.nix
    ];

  networking.hostName = "vormir"; # Define your hostname.

  services.xserver.resolutions = [ { x = 1920; y = 1080; } ];

  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

  environment.variables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = lib.mkDefault "1";
  };
}
