# dvalinn: a standalone server for mimir, kept apart from yggdrasil's
# services and backups. mimir runs from ~/mimir with Docker compose; its
# secrets come from sops (below).
#
# Installed with nixos-anywhere (disko lays out the disk):
#   nix run github:nix-community/nixos-anywhere -- --flake .#dvalinn root@<installer-ip>
# Then deployed from the laptop, never rebuilt on the box:
#   nixos-rebuild switch --flake .#dvalinn --target-host iammrinal0@dvalinn --sudo
{ config, pkgs, hostname, username, ... }:

{
  imports = [
    ../hardware/${hostname}.nix
    ../modules/nixos/system-label.nix
    ../modules/nixos/server-profile.nix
    ../modules/nixos/mimir-backup.nix
  ];

  modules.server.enable = true;

  # An EFI partition and one ext4 root. No LUKS: the disk is encrypted by
  # the host, and a passphrase at boot would stop it coming back on its own.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;

  networking.hostName = hostname;
  networking.useDHCP = true;

  time.timeZone = "Europe/Stockholm";

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" username ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "daily";
      randomizedDelaySec = "14m";
      options = "--delete-older-than 30d";
    };
  };

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Reached over the tailnet; the LAN gets SSH alone, for installs and repair.
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowAgentForwarding = "no";
      AllowTcpForwarding = "no";
      MaxAuthTries = 3;
      LogLevel = "VERBOSE";
      AllowUsers = [ username ];
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2VaKwjYmaBmrbVp14QFZBguI9ah8hC+sw91OYH6bg7 github@mrinalpurohit.in" # betazed
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    git-crypt
    docker-compose
    rsync
    vim
    jq
  ];

  programs.git = {
    enable = true;
    config = {
      user = import ../modules/git-identity.nix;
    };
  };

  # --- Secrets (sops) ---
  # Rendered into an env file only the compose user can read.
  sops = {
    defaultSopsFile = ../sops/dvalinn.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      OIDC_ISSUER = { };
      OIDC_CLIENT_ID = { };
      OIDC_CLIENT_SECRET = { };
      OIDC_ALLOWED_EMAILS = { };
      MIMIR_SESSION_SECRET = { };
    };
    templates."mimir.env" = {
      owner = username;
      mode = "0400";
      content = ''
        OIDC_ISSUER=${config.sops.placeholder.OIDC_ISSUER}
        OIDC_CLIENT_ID=${config.sops.placeholder.OIDC_CLIENT_ID}
        OIDC_CLIENT_SECRET=${config.sops.placeholder.OIDC_CLIENT_SECRET}
        OIDC_ALLOWED_EMAILS=${config.sops.placeholder.OIDC_ALLOWED_EMAILS}
        MIMIR_SESSION_SECRET=${config.sops.placeholder.MIMIR_SESSION_SECRET}
      '';
    };
  };

  services.mimir-backup = {
    enable = true;
    dir = "/home/${username}/mimir/vault";
    user = username;
    recipients = [
      "age1yk2lqwvacdnvce9phpks99yacrcd7vp49gtexnsskesntgh0pavsal6583" # betazed
      "age1wkd4qg6m5cajcasjznl6myjrrpua7s45pskx3c0jflxsjhxww92q5qu0x5" # offline recovery key
    ];
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
  };

  system.stateVersion = "26.05";
}
