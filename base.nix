{ lib, config, pkgs, ... }:

let aws_client_vpn = import ./pkgs/aws_client_vpn { inherit config lib pkgs; };
    emacsConfig = import ./config/emacs.nix { inherit pkgs; };
    secrets = [ "aws-vpn-ca" ];
    defaultPermissions = secret: {
    ${secret} = {
      mode = "0440";
      owner = config.users.users.iammrinal0.name;
      group = config.users.users.iammrinal0.group;
    };
  };

in {
  imports = [
    (import "${builtins.fetchTarball "https://github.com/rycee/home-manager/archive/master.tar.gz"}/nixos")
    (import "${builtins.fetchTarball "https://github.com/Mic92/sops-nix/archive/master.tar.gz"}/modules/sops")
    ./cache.nix
  ];

  nixpkgs.overlays = [
    (import (builtins.fetchTarball "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz"))
    (import ./overlays.nix)
  ];

  sops = {
    defaultSopsFile = ./sops/secrets.yaml;
    secrets = lib.foldl' lib.mergeAttrs { } (builtins.map defaultPermissions secrets);
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot = { enable = true; };
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config = {
    allowUnfree = true;
    pulseaudio = true;
    chromium = { enableWideVine = true; };
    packageOverrides = pkgs: {
      nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
        inherit pkgs;
      };
    };
  };

  nix = {
    autoOptimiseStore = true;
    extraOptions = ''
    keep-outputs = true
    keep-derivations = true
    '';
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    trustedUsers = [ "root" "iammrinal0" ];
  };

  time.timeZone = "Asia/Kolkata";

  environment = {
    systemPackages = [
      pkgs.atop
      pkgs.android-file-transfer
      aws_client_vpn
      pkgs.binutils
      pkgs.coreutils-full
      pkgs.git
      pkgs.ncdu
      pkgs.ntfs3g
      pkgs.openjdk
      pkgs.openssl
      pkgs.openvpn_aws
      pkgs.pptp
      pkgs.razergenie
      pkgs.sops
      pkgs.stow
      pkgs.tcpdump
      pkgs.traceroute
      pkgs.usbutils
      pkgs.vim
      pkgs.yubikey-personalization
      (pkgs.emacsWithPackagesFromUsePackage emacsConfig)
    ];
    variables = {
      QT_STYLE_OVERRIDE = lib.mkDefault "gtk2";
    };
  };

  services = {
    avahi = {
      enable = true;
      nssmdns = true;
      publish = {
        enable = true;
        addresses = true;
      };
    };
    udev.packages = [
      pkgs.yubikey-personalization
    ];
    dbus.packages = [ pkgs.blueman ];
    dnsmasq = { enable = true; };
    emacs = {
      enable = true;
      package = pkgs.emacsGcc;
      defaultEditor = true;
      install = true;
    };
    blueman = { enable = true; };
    openssh = { enable = true; };
    upower = { enable = true; };
    fwupd = { enable = true; };
    xserver = import ./services/xserver.nix { inherit pkgs; };
  };

  hardware = {
    bluetooth = {
      enable = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
      package = pkgs.bluezFull;
    };
    openrazer = { enable = true; };
    pulseaudio = {
      enable = true;
      extraModules = [ pkgs.pulseaudio-modules-bt ];
      package = pkgs.pulseaudioFull;
      support32Bit = true;
    };
  };

  virtualisation.docker = { enable = true; };

  programs = {
    adb = { enable = true; };
    light = { enable = true; };
    nm-applet = { enable = true; };
    ssh.startAgent = true;
  };

  networking = {
    firewall.allowedTCPPortRanges = [ { from=1714; to=1764; } ]; # KDE Connect Ports
    firewall.allowedUDPPortRanges = [ { from=1714; to=1764; } ]; # KDE Connect Ports
    firewall.allowedTCPPorts = [ 24800 ];
    firewall.allowedUDPPorts = [ 24800 1194 ]; # AWS Client VPN
    networkmanager = {
      enable = true;
      wifi.macAddress = "random";
      dns = "none";
    };
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };

  sound = { enable = true; };

  fonts = {
    fonts = [
      pkgs.cantarell-fonts
      pkgs.dejavu_fonts
      pkgs.emacs-all-the-icons-fonts
      pkgs.font-awesome
      pkgs.google-fonts
      pkgs.hasklig
      pkgs.iosevka
      pkgs.noto-fonts
      pkgs.source-code-pro
    ];
    fontconfig = { enable = true; };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.iammrinal0 = {
    isNormalUser = true;
    extraGroups = [ "adbusers" "audio" "docker" "keys" "networkmanager" "plugdev" "video" "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
  };

  security.sudo.extraRules = [{
    users = ["iammrinal0"];
    commands = [{
      command = "${aws_client_vpn}/bin/aws_client_vpn_connect";
      options = ["NOPASSWD"];
    } {
      command = "${pkgs.openvpn_aws}/bin/openvpn";
      options = ["NOPASSWD"];
    }];
  }];

  home-manager = {
    users = {
      iammrinal0 = ./home.nix;
    };
    useGlobalPkgs = true;
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?

}
