{ config, lib, pkgs, inputs, ... }:

with lib;

let cfg = config.modules.emacs;
in {
  options.modules.emacs = {
    enable = mkEnableOption "Enable Emacs configuration";

    package = mkOption {
      type = types.package;
      default = pkgs.emacs-unstable;
      description = "The Emacs package to use";
    };

    defaultEditor = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to make Emacs the default editor";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.emacs-overlay.overlays.default ];

    services.emacs = {
      enable = true;
      package = cfg.package;
      defaultEditor = cfg.defaultEditor;
      install = true;
    };

    fonts.packages = [ pkgs.emacs-all-the-icons-fonts ];
  };
}
