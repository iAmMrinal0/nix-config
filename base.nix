inputs@{ lib, config, pkgs, ... }:

let
  # emacsConfig =
  #  import ./config/emacs.nix { inherit (inputs) pkgs emacsConfiguration; };
  secrets = [ "service-access-host" "service-access-key" "nixpkgs-review" ];
  defaultPermissions = secret: {
    ${secret} = {
      mode = "0440";
      owner = config.users.users.iammrinal0.name;
      group = config.users.users.iammrinal0.group;
    };
  };

  vscodeExtensions = with pkgs.vscode-extensions;
    [
      ms-vsliveshare.vsliveshare
      ms-vscode-remote.remote-ssh
      justusadam.language-haskell
      dhall.vscode-dhall-lsp-server
      dhall.dhall-lang
      eamodio.gitlens
      github.vscode-pull-request-github
      bbenoist.nix
      pkief.material-icon-theme
      ms-azuretools.vscode-docker
      hashicorp.terraform
      jnoortheen.nix-ide
    ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace

      [
        {
          name = "codespaces";
          publisher = "github";
          version = "1.10.0";
          sha256 = "0b9lyjjfhq7k6wb18cfk7fbi9jlrc2qbq8fa42p2l6dzzid87z6k";
        }
        {
          name = "vscode-direnv";
          publisher = "rubymaniac";
          version = "0.0.2";
          sha256 = "1gml41bc77qlydnvk1rkaiv95rwprzqgj895kxllqy4ps8ly6nsd";
        }
        {
          name = "haskell";
          publisher = "haskell";
          version = "2.2.1";
          sha256 = "14p9g07zsb3da4ilaasgsdvh3wagfzayqr8ichsf6k5c952zi8fk";
        }
        {
          name = "gruvbox-themes";
          publisher = "tomphilbin";
          version = "1.0.0";
          sha256 = "sha256-DnwASBp1zvJluDc/yhSB87d0WM8PSbzqAvoICURw03c=";
        }
        {
          name = "fluent-icons";
          publisher = "miguelsolorio";
          version = "0.0.18";
          sha256 = "02zrlaq4f29vygisgsyx0nafcccq92mhms420qj0lgshipih0kdh";
        }
        {
          name = "vscode-emacs-friendly";
          publisher = "lfs";
          version = "0.9.0";
          sha256 = "sha256-YWu2a5hz0qGZvgR95DbzUw6PUvz17i1o4+eAUM/xjMg=";
        }
      ];

  vscode-with-extensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = vscodeExtensions;
  };

in
{

  #sops = {
  #  defaultSopsFile = ./sops/secrets.yaml;
  #  secrets =
  #    lib.foldl' lib.mergeAttrs { } (builtins.map defaultPermissions secrets);
  #};

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot = { enable = true; };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  nixpkgs.config = {
    allowUnfree = true;
    pulseaudio = true;
    chromium = { enableWideVine = true; };
    permittedInsecurePackages = [ "electron-9.4.4" ];
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
      dates = "weekly";
      options = "--delete-older-than 30d";
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
      vscode-with-extensions
    ];
    variables = { QT_STYLE_OVERRIDE = lib.mkDefault "gtk2"; };
  };

  security.pam.services.lightdm.enableGnomeKeyring = true;

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
    dbus.packages = [ pkgs.blueman pkgs.dconf pkgs.gcr ];
    dnsmasq = { enable = true; };
    #emacs = {
    #  enable = true;
    #  package = pkgs.emacsUnstable;
    #  defaultEditor = true;
    #  install = true;
    #};
    blueman = { enable = true; };
    openssh = { enable = true; };
    upower = { enable = true; };
    fwupd = { enable = true; };
    displayManager = {
      # lightdm = { enable = true; };
      defaultSession = "none+i3";
    };
    libinput = { enable = true; };
    xserver = import ./services/xserver.nix { inherit pkgs; };
    gvfs = { enable = true; };
    gnome.gnome-keyring.enable = true;
    tailscale.enable = true;
  };

  hardware = {
    bluetooth = {
      enable = true;
      settings = { General = { Enable = "Source,Sink,Media,Socket"; }; };
      package = pkgs.bluez;
    };
    openrazer = {
      enable = true;
      users = [ "iammrinal0" ];
    };
    pulseaudio = {
      enable = false;
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
    zsh =  { enable = true; };
    seahorse = { enable = true; };
  };

  networking = {
    firewall = {
      allowedTCPPortRanges = [{
        from = 1714;
        to = 1764;
      }]; # KDE Connect Ports
      allowedUDPPortRanges = [{
        from = 1714;
        to = 1764;
      }]; # KDE Connect Ports
      allowedTCPPorts = [ 24800 22 ];
      allowedUDPPorts = [ 24800 config.services.tailscale.port ];
      trustedInterfaces = [ "tailscale0" ];
      checkReversePath = "loose";
    };
    networkmanager = {
      enable = true;
      wifi.macAddress = "random";
      #dns = "none";
    };
  };

  # sound = { enable = true; };

  fonts = {
    packages = [
      pkgs.cantarell-fonts
      pkgs.emacs-all-the-icons-fonts
      pkgs.font-awesome
      pkgs.hasklig
      pkgs.iosevka
      pkgs.source-code-pro
      pkgs.nerdfonts
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
    extraSpecialArgs = {
      # emacsConfig = emacsConfig;
      inherit (inputs)
        zsh-autosuggestions zsh-you-should-use zsh-history-substring-search
        zsh-nix-shell;
    };
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "24.05"; # Did you read the comment?

}
