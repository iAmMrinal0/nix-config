{ lib, config, inputs, pkgs, ... }:

let
  secrets = [ "service-access-host" "service-access-key" "nixpkgs-review" ];
  defaultPermissions = secret: {
    ${secret} = {
      mode = "0440";
      owner = config.users.users.iammrinal0.name;
      group = config.users.users.iammrinal0.group;
    };
  };

in
{

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
    chromium = { enableWideVine = true; };
    permittedInsecurePackages = [ ];
  };

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes ca-derivations
      keep-outputs = true
      keep-derivations = true
    '';
    gc = {
      automatic = true;
      dates = "daily";
      randomizedDelaySec = "14m";
      options = "--delete-older-than 10d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "iammrinal0" ];
    };
  };

  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  environment = {
    systemPackages = [
      (pkgs.writeShellScriptBin "nixFlakes" ''
        exec ${pkgs.nixVersions.latest}/bin/nix --experimental-features "nix-command flakes" "$@"
      '')
      pkgs.atop
      pkgs.android-file-transfer
      pkgs.binutils
      pkgs.coreutils-full
      pkgs.docker-compose
      pkgs.git
      pkgs.libsecret
      pkgs.ncdu
      pkgs.nix-build-uncached
      pkgs.ntfs3g
      pkgs.openjdk
      pkgs.openssl
      pkgs.pinentry-gnome3
      pkgs.pptp
      pkgs.razergenie
      pkgs.sops
      pkgs.stow
      pkgs.tailscale
      pkgs.tcpdump
      pkgs.traceroute
      pkgs.usbutils
      pkgs.v4l-utils
      pkgs.vim
      pkgs.yubikey-personalization
      pkgs.bitwarden
    ];
    variables = { QT_STYLE_OVERRIDE = lib.mkDefault "gtk2"; };
  };

  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.rtkit.enable = true;

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
      };
    };
    udev.packages = [ pkgs.yubikey-personalization ];
    davfs2.enable = true;
    dbus.packages = [ pkgs.blueman pkgs.dconf pkgs.gcr pkgs.seahorse ];
    dnsmasq = { enable = true; };
    openssh = { enable = true; };
    upower = { enable = true; };
    fwupd = { enable = true; };
    libinput = { enable = true; };
    gvfs = { enable = true; };
    gnome.gnome-keyring.enable = true;
  };

  programs = {
    light = { enable = true; };
    ssh.startAgent = true;
    zsh = { enable = true; };
    seahorse = { enable = true; };
  };

  fonts = {
    packages = [
      pkgs.cantarell-fonts
      pkgs.font-awesome
      pkgs.hasklig
      pkgs.iosevka
      pkgs.source-code-pro
    ];
    fontconfig = { enable = true; };
  };
  
  modules = {
    audio = {
      enable = true;
      pulseaudio = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
    
    bluetooth = {
      enable = true;
      settings = { General = { Enable = "Source,Sink,Media,Socket"; }; };
    };
    
    displayManager = {
      enable = true;
      defaultSession = "none+i3";
      autoLogin = {
        enable = false;
        user = "iammrinal0";
      };
    };
    
    docker = {
      enable = true;
      addUserToGroup = true;
      installCompose = true;
    };
    
    networking = {
      enable = true;
      networkManager = {
        enable = true;
        wifi.macAddressRandomization = "random";
      };
      firewall = {
        enable = true;
      };
      extraHosts = ''
        127.0.0.1 bankid.local
        127.0.0.1 swish.local
        127.0.0.1 mss.swish.local
        127.0.0.1 mobilepay.local
        127.0.0.1 uc.local
        127.0.0.1 mock.local
        127.0.0.1 finsharkauth.local
        127.0.0.1 finsharkapi.local
        127.0.0.1 boozt.finance.local
        127.0.0.1 reepay.local
        127.0.0.1 reepay.checkout.local
        127.0.0.1 braintree.local
        127.0.0.1 slack.local
        127.0.0.1 paypal.local
        127.0.0.1 valitor.local
        127.0.0.1 clearhaus.local
        127.0.0.1 enablebanking.local
        127.0.0.1 przelewy24.local
        127.0.0.1 api.nordeaopenbanking.local
      '';
    };
    
    openrazer = {
      enable = true;
      addUser = true;
      installRazergenie = true;
    };
    
    printing = {
      enable = true;
    };
    
    tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "both";
      installPackage = true;
    };
    
    touchegg = {
      enable = true;
    };
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

  system.activationScripts.diff = ''
    if [[ -e /run/current-system ]]; then
      ${pkgs.nix}/bin/nix store diff-closures /run/current-system "$systemConfig"
    fi
  '';

  boot.tmp.useTmpfs = true;
  boot.tmp.cleanOnBoot = true;
  boot.plymouth.enable = true;
}
