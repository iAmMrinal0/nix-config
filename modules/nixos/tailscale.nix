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

    authKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        File containing a pre-authorized tailnet auth key (e.g. a sops
        secret path). When set, the machine joins the tailnet on first
        boot without interactive `tailscale up`.
      '';
    };
  };

  config = mkIf cfg.enable {
    # services.tailscale auto-adds cfg.package to environment.systemPackages.
    services.tailscale = {
      enable = true;
      package = pkgs.unstable.tailscale;
      openFirewall = cfg.openFirewall;
      useRoutingFeatures = cfg.useRoutingFeatures;
      authKeyFile = cfg.authKeyFile;
    };

    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
