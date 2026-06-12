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
          # Demote S/PDIF (IEC958) capture inputs so they never auto-become
          # the default *source*. The Targus dock exposes its digital
          # passthrough as `alsa_input...iec958-stereo`, and WirePlumber was
          # scoring it above the real mics and picking it as the default
          # input — but it's a digital passthrough, not a microphone, so it
          # captures silence. That broke every "default mic" consumer
          # (Discord, the Mod+Shift+m mute keybind, etc.). Match the IEC958
          # input generically (regex, not the dock's serial) so any dock with
          # an S/PDIF input is covered.
          {
            matches = [{ "node.name" = "~alsa_input\\..*iec958.*"; }];
            actions = {
              update-props = {
                "priority.session" = -100;
                "priority.driver" = -100;
              };
            };
          }
          # Prefer the laptop's built-in digital array mic (Mic1) as the
          # default source. Boosting it above the bluetooth-headset source
          # priority means connecting the WH-1000XM3 does NOT pull voice
          # capture onto the headset — which would force the bluetooth link
          # into mono HFP and wreck A2DP music quality. Voice stays on the
          # laptop mic; the headset stays in high-quality A2DP. An explicit
          # `wpctl set-default` still overrides this (WirePlumber persists the
          # manual choice); the priority only governs the automatic fallback.
          {
            matches = [{ "node.name" = "~alsa_input\\..*Mic1__source"; }];
            actions = {
              update-props = {
                "priority.session" = 3000;
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
