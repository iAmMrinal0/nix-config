{ config, lib, pkgs, ... }:

with lib;

let cfg = config.modules.tailscale;
in {
  options.modules.tailscale = {
    enable = mkEnableOption "Enable Tailscale VPN";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically open the firewall for Tailscale";
    };

    useRoutingFeatures = mkOption {
      type = types.enum [ "none" "client" "server" "both" ];
      default = "both";
      description = "Enable Tailscale subnet routing and exit node features";
    };

    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the tailscale package";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      package = pkgs.unstable.tailscale;
      openFirewall = cfg.openFirewall;
      useRoutingFeatures = cfg.useRoutingFeatures;
    };

    environment.systemPackages =
      mkIf cfg.installPackage [ pkgs.unstable.tailscale ];

    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
