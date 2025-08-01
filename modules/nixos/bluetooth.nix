{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.bluetooth;
in {
  options.modules.bluetooth = {
    enable = mkEnableOption "Enable bluetooth configuration";

    settings = mkOption {
      type = types.attrsOf (types.attrsOf types.str);
      default = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Privacy = "device";
          JustWorksRepairing = "always";
          Class = "0x000100";
          FastConnectable = true;
        };
      };
      description = "Bluetooth settings";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.bluez;
      description = "The bluetooth package to use";
    };
  };

  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      settings = cfg.settings;
      package = cfg.package;
    };

    services.blueman.enable = true;

    hardware.xpadneo.enable = true;
  };
}
