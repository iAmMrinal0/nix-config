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
  };

  config = mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      pulse.enable = cfg.pulseaudio;
      alsa.enable = cfg.alsa.enable;
      alsa.support32Bit = cfg.alsa.support32Bit;
    };

    security.rtkit.enable = cfg.rtkit;

    nixpkgs.config.pulseaudio = cfg.pulseaudio;
  };
}
