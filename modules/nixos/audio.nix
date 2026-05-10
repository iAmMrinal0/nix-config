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

      wireplumber.extraConfig."51-internal-audio" = {
        "monitor.alsa.rules" = [
          # Force the unified UCM profile so Speaker and Headphones share
          # one profile and switch via jack auto-detection. Without this,
          # the card comes up in a Headphones-only profile and laptop
          # speakers are unreachable.
          {
            matches = [{ "device.name" = "~alsa_card\\..*"; }];
            actions = {
              update-props = {
                "api.alsa.split-enable" = false;
              };
            };
          }
          # Demote HDMI/DP outputs so an external monitor never auto-becomes
          # the default sink. Bluetooth sinks have a higher priority.session
          # by default, so they'll still take over when connected.
          {
            matches = [{ "node.name" = "~alsa_output\\..*HDMI.*"; }];
            actions = {
              update-props = {
                "priority.session" = -100;
                "priority.driver" = -100;
              };
            };
          }
        ];
      };
    };

    security.rtkit.enable = cfg.rtkit;

    nixpkgs.config.pulseaudio = cfg.pulseaudio;
  };
}
