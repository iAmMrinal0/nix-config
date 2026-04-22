{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.audio;
in {
  options.modules.audio = {
    enable = mkEnableOption "Enable audio configuration";

    pulseaudio = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable PulseAudio compatibility";
    };

    alsa = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable ALSA support";
      };

      support32Bit = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable 32-bit ALSA support";
      };
    };

    rtkit = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable rtkit for audio";
    };

    switchOnConnect = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Load PulseAudio's module-switch-on-connect so a newly-connected
        device (e.g. Bluetooth headset) automatically becomes the default
        sink/source and existing streams move to it. Requires pulse
        compatibility.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      pulse.enable = cfg.pulseaudio;
      alsa.enable = cfg.alsa.enable;
      alsa.support32Bit = cfg.alsa.support32Bit;

      extraConfig.pipewire-pulse."92-switch-on-connect" =
        mkIf (cfg.pulseaudio && cfg.switchOnConnect) {
          "pulse.cmd" = [{
            cmd = "load-module";
            args = "module-switch-on-connect";
            flags = [ ];
          }];
        };
    };

    security.rtkit.enable = cfg.rtkit;

    nixpkgs.config.pulseaudio = cfg.pulseaudio;
  };
}
