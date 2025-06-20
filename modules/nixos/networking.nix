{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.networking;
in {
  options.modules.networking = {
    enable = mkEnableOption "Enable networking configuration";

    networkManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable NetworkManager";
      };

      wifi = {
        macAddressRandomization = mkOption {
          type = types.enum [ "default" "random" "stable" "permanent" ];
          default = "random";
          description = "MAC address randomization policy";
        };
      };
    };

    firewall = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable the firewall";
      };

      allowedTCPPorts = mkOption {
        type = types.listOf types.port;
        default = [ 22 ];
        description = "TCP ports to open";
      };

      allowedUDPPorts = mkOption {
        type = types.listOf types.port;
        default = [ ];
        description = "UDP ports to open";
      };
    };

    extraHosts = mkOption {
      type = types.lines;
      default = "";
      description = "Extra entries for /etc/hosts";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      networkmanager = mkIf cfg.networkManager.enable {
        enable = true;
        wifi.macAddress = cfg.networkManager.wifi.macAddressRandomization;
      };

      firewall = mkIf cfg.firewall.enable {
        enable = true;
        allowedTCPPorts = cfg.firewall.allowedTCPPorts;
        allowedUDPPorts = cfg.firewall.allowedUDPPorts;
      };

      extraHosts = cfg.extraHosts;
    };

    programs.nm-applet.enable = cfg.networkManager.enable;
  };
}
