# NixOS config for ThinkPad X1 Carbon
{ config, pkgs, ... }:

{
  imports =
    [ ../hardware/carbon.nix
      ../base.nix
    ];

  networking.hostName = "vormir"; # Define your hostname.
  hardware.bluetooth = {
    enable = true;
    extraConfig = "
  [General]
  Enable=Source,Sink,Media,Socket";
  };
  services.dbus.packages = [ pkgs.blueman ];

}
