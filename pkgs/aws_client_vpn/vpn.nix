{ config, pkgs, ... }:

pkgs.writeText "vpn.conf" ''
  client
  dev tun
  proto tcp
  nobind
  persist-key
  persist-tun
  remote-cert-tls server
  cipher AES-256-GCM
  ca ${config.sops.secrets.aws-vpn-ca.path}

  auth-nocache
  reneg-sec 0
''
