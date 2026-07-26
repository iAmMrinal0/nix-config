{ config, pkgs, lib, username, ... }:

let
  kronorUser = config.kronor.user;
  kronorHome = config.users.users.${kronorUser}.home;
  # Grouped with the SOCKS proxies below (11091/11092). The kronor dev stack
  # derives every host port as base+slot*10000 (slots 0-4, _dev/derive-ports.sh),
  # so any base it uses is occupied at +10000/+20000/... too. We sit on the 1090
  # base, which no dev service uses, keeping all three proxy ports clear across
  # every slot. (18080 = Hasura slot 1; 11080 = mockserver slot 1 — both taken.)
  pacPort = 11090;
  pacUrl = "http://127.0.0.1:${toString pacPort}/kronor.pac";
  pacRoot = pkgs.writeTextDir "kronor.pac" ''
    function FindProxyForURL(url, host) {
      if (dnsDomainIs(host, ".internal.staging.kronor.io")) {
        return "SOCKS5 127.0.0.1:${toString namespaces.kronor-staging.browserProxyPort}";
      }

      if (dnsDomainIs(host, ".internal.production.kronor.io")) {
        return "SOCKS5 127.0.0.1:${toString namespaces.kronor-production.browserProxyPort}";
      }

      return "DIRECT";
    }
  '';
  namespaceNsswitch = pkgs.writeText "kronor-nsswitch.conf" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList
        (database: sources:
          "${database}: ${lib.concatStringsSep " " sources}")
        (config.system.nssDatabases // { hosts = [ "files" "dns" ]; })
    )
    + "\n"
  );

  namespaces = {
    kronor-staging = {
      environment = "staging";
      hostInterface = "veth-kstg";
      namespaceInterface = "veth0";
      namespacePeer = "veth-kstg0";
      hostAddress = "10.200.1.1";
      namespaceAddress = "10.200.1.2";
      prefixLength = 24;
      # On the 1091 base (see pacPort note): free across all dev-stack slots.
      # The old 1081 base collided with slot 1 (mockserver is 1080, and isosim
      # historically published on 1081/1082).
      browserProxyPort = 11091;
      vpnConfig = config.sops.secrets.kronor-openvpn-staging.path;
    };

    kronor-production = {
      environment = "production";
      hostInterface = "veth-kprod";
      namespaceInterface = "veth0";
      namespacePeer = "veth-kprod0";
      hostAddress = "10.200.2.1";
      namespaceAddress = "10.200.2.2";
      prefixLength = 24;
      browserProxyPort = 11092;
      vpnConfig = config.sops.secrets.kronor-openvpn-production.path;
    };
  };

  mkNamespaceService = name: cfg: {
    description = "Network namespace ${name}";

    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    path = [ pkgs.iproute2 pkgs.iptables ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      # Remove any incomplete state left by a previous failed start.
      ip netns delete ${name} 2>/dev/null || true
      ip link delete ${cfg.hostInterface} 2>/dev/null || true

      ip netns add ${name}

      ip link add ${cfg.hostInterface} \
        type veth \
        peer name ${cfg.namespacePeer}

      ip link set ${cfg.namespacePeer} netns ${name}

      ip address add \
        ${cfg.hostAddress}/${toString cfg.prefixLength} \
        dev ${cfg.hostInterface}

      ip link set ${cfg.hostInterface} up

      ip -n ${name} link set lo up

      ip -n ${name} link set ${cfg.namespacePeer} name ${cfg.namespaceInterface}

      ip -n ${name} address add \
        ${cfg.namespaceAddress}/${toString cfg.prefixLength} \
        dev ${cfg.namespaceInterface}

      ip -n ${name} link set ${cfg.namespaceInterface} up

      ip -n ${name} route add default via ${cfg.hostAddress}

      # Dante must listen before the VPN exists so the first SOCKS request can
      # perform the DNS lookup that activates OpenVPN. It therefore cannot use
      # tun0 as its configured external interface and uses veth0 instead.
      #
      # Once tun0 appears, the kernel routes private destinations through it,
      # but Dante's outbound sockets still use ${cfg.namespaceAddress}, the
      # veth0 address, as their source. The remote AWS network has no route
      # back to that locally invented address. Masquerade only packets leaving
      # through tun* so they use the VPN-assigned tunnel address. Conntrack
      # translates replies back to ${cfg.namespaceAddress} for Dante.
      ip netns exec ${name} iptables -t nat -A POSTROUTING \
        -s ${cfg.namespaceAddress}/32 -o 'tun+' -j MASQUERADE
    '';

    preStop = ''
      ip netns delete ${name} 2>/dev/null || true
      ip link delete ${cfg.hostInterface} 2>/dev/null || true
    '';
  };

  mkVpnService = name: cfg: {
    description = "Kronor ${cfg.environment} OpenVPN tunnel";
    requires = [ "netns-${name}.service" ];
    after = [ "netns-${name}.service" ];

    unitConfig = {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };

    serviceConfig = {
      Type = "simple";
      NetworkNamespacePath = "/run/netns/${name}";
      RuntimeDirectory = "kronor-vpn-${cfg.environment}";
      RuntimeDirectoryMode = "0700";
      Restart = "no";
      ExecStart = pkgs.writeShellScript "kronor-vpn-${cfg.environment}" ''
        # Fail at the ask-password step if the OTP can't be obtained, instead
        # of execing openvpn with a username-only credentials file.
        set -euo pipefail
        umask 077
        credentials="$RUNTIME_DIRECTORY/auth-user-pass"
        uid=$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg kronorUser})

        printf '%s\n' 'mrinal@kronor.io' > "$credentials"
        ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg kronorUser} -- \
          ${pkgs.coreutils}/bin/env \
            HOME=${lib.escapeShellArg kronorHome} \
            XDG_RUNTIME_DIR="/run/user/$uid" \
            ${pkgs.systemd}/bin/systemd-ask-password \
              --user \
              --no-tty \
              --echo=no \
              --timeout=120 \
              --id=kronor-vpn:${cfg.environment} \
              "Kronor ${cfg.environment} VPN OTP" \
          >> "$credentials"

        exec ${pkgs.openvpn}/bin/openvpn \
          --config ${lib.escapeShellArg cfg.vpnConfig} \
          --auth-user-pass "$credentials" \
          --inactive 600
      '';
    };
  };

  mkDnsSocket = name: cfg: {
    description = "On-demand DNS socket for Kronor ${cfg.environment}";
    wantedBy = [ "multi-user.target" ];
    requires = [ "netns-${name}.service" ];
    after = [ "sysinit.target" "netns-${name}.service" ];
    before = [ "multi-user.target" "shutdown.target" ];
    conflicts = [ "shutdown.target" ];

    unitConfig.DefaultDependencies = false;
    socketConfig = {
      ListenStream = "${cfg.hostAddress}:53";
      NoDelay = true;
    };
  };

  mkDnsProxyService = name: cfg: {
    description = "On-demand DNS proxy for Kronor ${cfg.environment}";
    requires = [ "kronor-vpn-${cfg.environment}.service" ];
    # bindsTo, not just requires: the VPN exits on its own (--inactive), and
    # without stop propagation a client retrying DNS keeps the stale proxy
    # alive past exit-idle-time forever, wedging every lookup at 30s.
    bindsTo = [ "kronor-vpn-${cfg.environment}.service" ];
    after = [ "kronor-vpn-${cfg.environment}.service" ];

    serviceConfig = {
      NetworkNamespacePath = "/run/netns/${name}";
      TimeoutStartSec = 180;
      ExecStartPre = pkgs.writeShellScript "wait-for-kronor-${cfg.environment}-dns" ''
        for _ in $(${pkgs.coreutils}/bin/seq 1 120); do
          if ${pkgs.iproute2}/bin/ip route get 172.16.0.2 \
            | ${pkgs.gnugrep}/bin/grep -qE ' dev (tun|tap)'; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done

        echo "Timed out waiting for the ${cfg.environment} VPN route" >&2
        exit 1
      '';
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=30s 172.16.0.2:53";
    };
  };

  mkSocksService = name: cfg:
    let
      sockdConfig = pkgs.writeText "sockd-${cfg.environment}.conf" ''
        logoutput: stderr

        internal.protocol: ipv4
        internal: ${cfg.namespaceAddress} port = 1080

        external.protocol: ipv4
        external: ${cfg.namespaceInterface}

        user.privileged: root
        user.unprivileged: nobody

        clientmethod: none
        socksmethod: none

        client pass {
          from: ${cfg.hostAddress}/32 to: 0.0.0.0/0
        }

        socks pass {
          from: ${cfg.hostAddress}/32 to: 0.0.0.0/0
          command: connect
        }
      '';
    in
    {
      description = "SOCKS5 gateway for Kronor ${cfg.environment}";
      wantedBy = [ "multi-user.target" ];
      requires = [ "netns-${name}.service" ];
      after = [ "netns-${name}.service" ];

      serviceConfig = {
        NetworkNamespacePath = "/run/netns/${name}";
        BindReadOnlyPaths = [
          "/etc/netns/${name}/resolv.conf:/etc/resolv.conf"
          "/etc/netns/${name}/nsswitch.conf:/etc/nsswitch.conf"
        ];
        InaccessiblePaths = [ "/run/nscd/socket" ];
        RuntimeDirectory = "kronor-socks-${cfg.environment}";
        ExecStart = "${pkgs.dante}/bin/sockd -f ${sockdConfig} -p /run/kronor-socks-${cfg.environment}/sockd.pid";
        Restart = "on-failure";
        RestartSec = 2;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

  mkBrowserSocket = cfg: {
    description = "On-demand browser proxy socket for Kronor ${cfg.environment}";
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "127.0.0.1:${toString cfg.browserProxyPort}";
      NoDelay = true;
    };
  };

  mkBrowserProxyService = name: cfg: {
    description = "On-demand browser proxy for Kronor ${cfg.environment}";
    requires = [
      "kronor-vpn-${cfg.environment}.service"
      "kronor-socks-${cfg.environment}.service"
    ];
    bindsTo = [ "kronor-vpn-${cfg.environment}.service" ];
    after = [
      "kronor-vpn-${cfg.environment}.service"
      "kronor-socks-${cfg.environment}.service"
    ];

    serviceConfig = {
      TimeoutStartSec = 180;
      ExecStartPre = pkgs.writeShellScript "wait-for-kronor-${cfg.environment}-browser" ''
        for _ in $(${pkgs.coreutils}/bin/seq 1 120); do
          if ${pkgs.iproute2}/bin/ip netns exec ${name} \
            ${pkgs.iproute2}/bin/ip route get 172.16.0.2 \
            | ${pkgs.gnugrep}/bin/grep -qE ' dev (tun|tap)'; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done

        echo "Timed out waiting for the ${cfg.environment} VPN route" >&2
        exit 1
      '';
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=30s ${cfg.namespaceAddress}:1080";
    };
  };

in
{
  options.kronor.user = lib.mkOption {
    type = lib.types.str;
    default = username;
    description = "User whose Bitwarden vault (via rbw) holds the Kronor VPN OTP entries.";
  };

  config = {
  # net.ipv4.ip_forward (needed for the netns NAT) is already set by
  # modules/nixos/tailscale.nix.

  # Keep the host on Tailscale's MagicDNS resolver.
  networking.nameservers = [ "100.100.100.100" ];

  networking.nat = {
    enable = true;
    # No externalInterface: the laptop roams between wifi and dock ethernet,
    # so masquerade the netns ranges on whatever uplink is active.
    internalInterfaces = [ "veth-kstg" "veth-kprod" ];
    internalIPs = [
      "10.200.1.0/24"
      "10.200.2.0/24"
    ];
  };

  # dnsmasq (base.nix) binds :53 on the wildcard address by default, which
  # would steal the on-demand DNS sockets' 10.200.x.1:53. bind-dynamic binds
  # per-address as interfaces appear (laptop roaming) and skips the veths.
  services.dnsmasq.settings = {
    bind-dynamic = true;
    except-interface = [ "veth-kstg" "veth-kprod" ];
  };

  networking.firewall.interfaces =
    lib.mapAttrs
      (_: _: {
        allowedTCPPorts = [ 53 ];
      })
      {
        veth-kstg = { };
        veth-kprod = { };
      };

  systemd.services =
    lib.mapAttrs'
      (name: cfg:
        lib.nameValuePair
          "netns-${name}"
          (mkNamespaceService name cfg))
      namespaces
    // lib.mapAttrs'
      (_: cfg:
        lib.nameValuePair
          "kronor-vpn-${cfg.environment}"
          (mkVpnService "kronor-${cfg.environment}" cfg))
      namespaces
    // lib.mapAttrs'
      (_: cfg:
        lib.nameValuePair
          "kronor-dns-${cfg.environment}"
          (mkDnsProxyService "kronor-${cfg.environment}" cfg))
      namespaces
    // lib.mapAttrs'
      (_: cfg:
        lib.nameValuePair
          "kronor-socks-${cfg.environment}"
          (mkSocksService "kronor-${cfg.environment}" cfg))
      namespaces
    // lib.mapAttrs'
      (_: cfg:
        lib.nameValuePair
          "kronor-browser-${cfg.environment}"
          (mkBrowserProxyService "kronor-${cfg.environment}" cfg))
      namespaces
    // {
      kronor-pac = {
        description = "Kronor proxy auto-configuration server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${pacRoot} --addr 127.0.0.1 --port ${toString pacPort} --no-listing --default-mimetype application/x-ns-proxy-autoconfig";
          Restart = "on-failure";
          RestartSec = 2;

          DynamicUser = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };
    };

  systemd.sockets =
    lib.mapAttrs'
      (_: cfg:
        lib.nameValuePair
          "kronor-dns-${cfg.environment}"
          (mkDnsSocket "kronor-${cfg.environment}" cfg))
      namespaces
    // lib.mapAttrs'
      (_: cfg:
        lib.nameValuePair
          "kronor-browser-${cfg.environment}"
          (mkBrowserSocket cfg))
      namespaces;

  environment.etc."netns/kronor-staging/resolv.conf".text = ''
    nameserver 10.200.1.1
    nameserver 172.16.0.2
    options use-vc timeout:30 attempts:1
  '';

  environment.etc."netns/kronor-production/resolv.conf".text = ''
    nameserver 10.200.2.1
    nameserver 172.16.0.2
    options use-vc timeout:30 attempts:1
  '';

  environment.etc."netns/kronor-staging/nsswitch.conf".source = namespaceNsswitch;
  environment.etc."netns/kronor-production/nsswitch.conf".source = namespaceNsswitch;

  programs.chromium = {
    enable = true;
    extraOpts = {
      ProxyMode = "pac_script";
      ProxyPacUrl = pacUrl;
    };
  };
  };
}
