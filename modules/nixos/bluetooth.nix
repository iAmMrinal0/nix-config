{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.bluetooth;
in {
  options.modules.bluetooth = {
    enable = mkEnableOption "Enable bluetooth configuration";

    settings = mkOption {
      type = types.attrsOf (types.attrsOf (types.oneOf [ types.str types.bool ]));
      default = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
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
