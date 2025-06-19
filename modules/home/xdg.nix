{ config, pkgs, lib, ... }:

{
  imports = [
    ./xdg/main.nix
    ./xdg/dconf.nix
  ];
  
  personal.dconf = {
    enable = true;
    sound.eventSounds = false;
    appearance.preferDarkTheme = true;
  };
}
