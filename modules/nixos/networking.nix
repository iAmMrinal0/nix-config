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

        profiles = mkOption {
          type = types.attrsOf types.attrs;
          default = { };
          description = ''
            Declarative NetworkManager wifi profiles, in
            networking.networkmanager.ensureProfiles.profiles format.
            Reference PSKs as $VARIABLE; values are substituted from the
            sops-managed wifi-env secret at activation time.
          '';
          example = literalExpression ''
            {
              home = {
                connection = {
                  id = "home";
                  type = "wifi";
                };
                wifi.ssid = "MyHomeSSID";
                wifi-security = {
                  key-mgmt = "wpa-psk";
                  psk = "$WIFI_HOME_PSK";
                };
              };
            }
          '';
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

        ensureProfiles = mkIf (cfg.networkManager.wifi.profiles != { }) {
          environmentFiles = [ config.sops.secrets."wifi-env".path ];
          profiles = cfg.networkManager.wifi.profiles;
        };
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
