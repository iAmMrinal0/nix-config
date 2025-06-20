{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.touchegg;
in {
  options.modules.touchegg = {
    enable = mkEnableOption "Enable touchegg gesture support";
  };

  config = mkIf cfg.enable { services.touchegg.enable = true; };
}
