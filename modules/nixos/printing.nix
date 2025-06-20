{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.printing;
in {
  options.modules.printing = {
    enable = mkEnableOption "Enable printing support";

    drivers = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional printer drivers to install";
    };
  };

  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = cfg.drivers;
    };
  };
}
