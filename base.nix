# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

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
    (import (builtins.fetchTarball {
      url = https://github.com/nix-community/emacs-overlay/archive/master.tar.gz;
    }))
    (import ./overlays.nix)
  ];

  sops = {
    defaultSopsFile = ./sops/secrets.yaml;
    secrets = lib.foldl' lib.mergeAttrs { } (builtins.map defaultPermissions secrets);
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
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
    '';
  };

  # Cloudflare DNS servers
  networking = {
    networkmanager = {
      enable = true;
      wifi.macAddress = "random";
      dns = "none";
    };
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    atop
    android-file-transfer
    aws_client_vpn
    binutils
    coreutils-full
    git
    ncdu
    ntfs3g
    openjdk
    openssl
    openvpn_aws
    pptp
    razergenie
    sops
    stow
    tcpdump
    traceroute
    usbutils
    vim
    yubikey-personalization
    (emacsWithPackagesFromUsePackage emacsConfig)
  ];

  environment.variables = {
    QT_STYLE_OVERRIDE = lib.mkDefault "gtk2";
  };

  services.avahi = {
    enable = true;
    nssmdns = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  services.udev.packages = with pkgs; [
    yubikey-personalization
  ];

  services.dbus.packages = [ pkgs.blueman ];
  services.dnsmasq.enable = true;
  services.emacs = {
    enable = true;
    package = pkgs.emacsGcc;
    defaultEditor = true;
    install = true;
  };
  services.etcd.enable = true;
  services.blueman.enable = true;
  services.upower.enable = true;

  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
    package = pkgs.bluezFull;
  };

  hardware.openrazer.enable = true;

  virtualisation.docker.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };
  programs.adb.enable = true;
  programs.light.enable = true;
  programs.nm-applet.enable = true;
  programs.ssh.startAgent = true;

  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPortRanges = [ { from=1714; to=1764; } ]; # KDE Connect Ports
  networking.firewall.allowedUDPPortRanges = [ { from=1714; to=1764; } ]; # KDE Connect Ports
  networking.firewall.allowedTCPPorts = [ 24800 ];
  networking.firewall.allowedUDPPorts = [ 24800 1194 ]; # AWS Client VPN

  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    extraModules = [ pkgs.pulseaudio-modules-bt ];
    package = pkgs.pulseaudioFull;
    support32Bit = true;
  };

  fonts = {
    fonts = with pkgs; [
      cantarell-fonts
      dejavu_fonts
      emacs-all-the-icons-fonts
      font-awesome
      google-fonts
      hasklig
      iosevka
      noto-fonts
      source-code-pro
    ];
    fontconfig.enable = true;
  };

  services.fwupd.enable = true;

  services.xserver = {
    enable = true;
    exportConfiguration = true;
    displayManager = {
      lightdm.enable = true;
      defaultSession = "none+i3";
    };
    desktopManager = {
      xterm.enable = false;
    };
    libinput.enable = true;

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu
        rofi
        i3status
        i3lock
        i3blocks
      ];
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.iammrinal0 = {
    isNormalUser = true;
    extraGroups = [ "adbusers" "audio" "docker" "keys" "networkmanager" "plugdev" "video" "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
  };

  security.sudo.extraRules = [
    { users = ["iammrinal0"];
      commands = [
        {command = "${aws_client_vpn}/bin/aws_client_vpn_connect"; options = ["NOPASSWD"]; }
        {command = "${pkgs.openvpn_aws}/bin/openvpn"; options = ["NOPASSWD"]; }
      ];
    }
  ];

  home-manager.users.iammrinal0 = ./home.nix;
  home-manager.useGlobalPkgs = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.09"; # Did you read the comment?

}
