{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.personal.dconf;
in
{
  options.personal.dconf = {
    enable = mkEnableOption "dconf settings";
    
    sound = {
      eventSounds = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable GNOME event sounds";
      };
    };
    
    appearance = {
      preferDarkTheme = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to prefer dark theme for applications";
      };
    };
  };

  config = mkIf cfg.enable {
    dconf.settings = {
      "gnome/desktop/sound" = { 
        event-sounds = cfg.sound.eventSounds;
      };
      
      "org/gnome/desktop/interface" = mkIf cfg.appearance.preferDarkTheme {
        color-scheme = "prefer-dark";
      };
    };
  };
}
