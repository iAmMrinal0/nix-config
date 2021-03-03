# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, pkgs, ... }:

let aws_client_vpn = pkgs.callPackage ./pkgs/aws_client_vpn { };

in {
  imports = [
    (import "${builtins.fetchTarball https://github.com/rycee/home-manager/archive/master.tar.gz}/nixos")
    ./cache.nix
  ];

  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = https://github.com/nix-community/emacs-overlay/archive/master.tar.gz;
    }))
    (import ./overlays.nix)
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config = {
    allowUnfree = true;
    pulseaudio = true;
    chromium = { enableWideVine = true; };
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
    pptp
    razergenie
    stow
    tcpdump
    traceroute
    usbutils
    vim
    yubikey-personalization
    (emacsWithPackagesFromUsePackage {
      config = "${pkgs.fetchFromGitHub {
        owner = "iammrinal0";
        repo = ".emacs.d";
        rev = "2532f617ab297678c9a582cdd425037ba3421375";
        sha256 = "0a9dm7zhda8yv61r5is69knazbycircbg4jq3l5zingpn6wdhl0m";
      }}/init.el";
      package = pkgs.emacsGcc;
      extraEmacsPackages = epkgs: (with epkgs; [
        ace-window
        ag
        all-the-icons
        anzu
        avy
        bind-key
        dhall-mode
        diminish
        direnv
        editorconfig
        etcdctl
        exec-path-from-shell
        expand-region
        flycheck
        free-keys
        git-gutter
        groovy-mode
        gruvbox-theme
        haskell-mode
        hasky-extensions
        helm
        helm-ag
        helm-projectile
        hungry-delete
        hydra
        keychain-environment
        keyfreq
        lsp-haskell
        lsp-mode
        lsp-ui
        magit
        markdown-mode
        multiple-cursors
        nix-buffer
        nix-mode
        org-bullets
        pdf-tools
        projectile
        rainbow-delimiters
        rainbow-mode
        smart-mode-line
        smartparens
        use-package
        web-mode
        which-key
        yaml-mode
        yasnippet
        zerodark-theme
        zop-to-char
      ]);
    })
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
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPortRanges = [ { from=1714; to=1764; } ]; # KDE Connect Ports
  networking.firewall.allowedUDPPortRanges = [ { from=1714; to=1764; } ]; # KDE Connect Ports
  networking.firewall.allowedTCPPorts = [ 24800 ];
  networking.firewall.allowedUDPPorts = [ 24800 1194 ]; # AWS Client VPN
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
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
      # font-awesome_4
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
    extraGroups = [ "adbusers" "audio" "docker" "networkmanager" "plugdev" "video" "wheel" ]; # Enable ‘sudo’ for the user.
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
