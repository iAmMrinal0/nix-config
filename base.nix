{ lib, config, pkgs, ... }:

let
  emacsConfig = import ./config/emacs.nix { inherit pkgs; };
  secrets = [ "aws-vpn-ca" ];
  defaultPermissions = secret: {
    ${secret} = {
      mode = "0440";
      owner = config.users.users.iammrinal0.name;
      group = config.users.users.iammrinal0.group;
    };
  };

  home-manager = builtins.fetchGit {
    url = "https://github.com/nix-community/home-manager.git";
    rev = "41101d0e62fe3cdb76e8e64349a2650da1433dd4";
    ref = "master";
  };

  sops-nix = builtins.fetchTarball {
    url =
      "https://github.com/Mic92/sops-nix/archive/ec2800174de5a7be8ec5b144819af2c7de77abe2.tar.gz";
    sha256 = "1s430ml7p6aa950xsm6rblk0cgkb0a0adgk73mjyhqmb68hnbb2k";
  };

  emacs-overlay = builtins.fetchTarball {
    url =
      "https://github.com/nix-community/emacs-overlay/archive/40e6376f2d3fe4911122ae78569243aa929888b2.tar.gz";
    sha256 = "11jjx97vp2xyndkajyl743plf1dg2i8d91wbv82kxv7ak0c3z3r2";
  };

  nur = builtins.fetchTarball {
    url =
      "https://github.com/nix-community/NUR/archive/6c4a43390829ad08bc310f41700c95dfdbbe78e6.tar.gz";
    sha256 = "14pbhsnfm9gmwb60h80f9ji23cgqgbqimslgnw22h0aamsybgznp";
  };

in {
  imports = [
    (import "${home-manager}/nixos")
    (import "${sops-nix}/modules/sops")
    ./cache.nix
  ];

  nixpkgs.overlays = [ (import emacs-overlay) ];

  sops = {
    defaultSopsFile = ./sops/secrets.yaml;
    secrets =
      lib.foldl' lib.mergeAttrs { } (builtins.map defaultPermissions secrets);
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot = { enable = true; };
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config = {
    allowUnfree = true;
    pulseaudio = true;
    chromium = { enableWideVine = true; };
    packageOverrides = pkgs: { nur = import nur { inherit pkgs; }; };
  };

  nix = {
    autoOptimiseStore = true;
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes ca-derivations ca-references
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
      (pkgs.writeShellScriptBin "nixFlakes" ''
        exec ${pkgs.nixUnstable}/bin/nix --experimental-features "nix-command flakes" "$@"
      '')
      pkgs.atop
      pkgs.android-file-transfer
      pkgs.binutils
      pkgs.coreutils-full
      pkgs.git
      pkgs.ncdu
      pkgs.ntfs3g
      pkgs.openjdk
      pkgs.openssl
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
    variables = { QT_STYLE_OVERRIDE = lib.mkDefault "gtk2"; };
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
    udev.packages = [ pkgs.yubikey-personalization ];
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
      settings = { General = { Enable = "Source,Sink,Media,Socket"; }; };
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
    firewall.allowedTCPPortRanges = [{
      from = 1714;
      to = 1764;
    }]; # KDE Connect Ports
    firewall.allowedUDPPortRanges = [{
      from = 1714;
      to = 1764;
    }]; # KDE Connect Ports
    firewall.allowedTCPPorts = [ 24800 ];
    firewall.allowedUDPPorts = [ 24800 ];
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
    extraGroups = [
      "adbusers"
      "audio"
      "docker"
      "keys"
      "networkmanager"
      "plugdev"
      "video"
      "wheel"
    ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
  };

  home-manager = {
    users = { iammrinal0 = ./home.nix; };
    useGlobalPkgs = true;
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?

}
