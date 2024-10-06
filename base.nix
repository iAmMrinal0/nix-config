inputs@{ lib, config, pkgs, ... }:

let
  emacsConfig =
   import ./config/emacs.nix { inherit (inputs) pkgs emacsConfiguration; };
  secrets = [ "service-access-host" "service-access-key" "nixpkgs-review" ];
  defaultPermissions = secret: {
    ${secret} = {
      mode = "0440";
      owner = config.users.users.iammrinal0.name;
      group = config.users.users.iammrinal0.group;
    };
  };

  vscodeExtensions = with pkgs.vscode-marketplace;
    [
      ms-vscode-remote.vscode-remote-extensionpack
      ms-vscode.remote-explorer
      ms-vsliveshare.vsliveshare
      ms-python.vscode-pylance
      ms-python.python
      github.copilot
      github.copilot-chat
      # lfs.vscode-emacs-friendly
    ] ++ (with pkgs.open-vsx; [
      ahmadalli.vscode-nginx-conf
      bbenoist.nix
      berberman.vscode-cabal-fmt
      bierner.markdown-mermaid
      bigmoon.language-yesod
      davidanson.vscode-markdownlint
      dhall.dhall-lang
      dhall.vscode-dhall-lsp-server
      dksedgwick.xstviz
      eamodio.gitlens
      editorconfig.editorconfig
      github.vscode-pull-request-github
      hashicorp.terraform
      haskell.haskell
      jdinhlife.gruvbox
      jnoortheen.nix-ide
      jock.svg
      joeandaverde.sqitch-plan
      justusadam.language-haskell
      mel-brown.haskell-yesod-quasiquotes
      miguelsolorio.fluent-icons
      mkhl.direnv
      ms-azuretools.vscode-docker
      ms-python.black-formatter
      ms-vscode-remote.remote-ssh
      ms-vsliveshare.vsliveshare
      pkief.material-icon-theme
      raynigon.nginx-formatter
      redhat.vscode-yaml
      statelyai.stately-vscode
      vscodeemacs.emacs
      # lfs.vscode-emacs-friendly
    ]);

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
      vscode-with-extensions
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
    dbus.packages = [ pkgs.blueman pkgs.dconf pkgs.gcr pkgs.gnome.seahorse ];
    dnsmasq = { enable = true; };
    emacs = {
     enable = true;
     package = pkgs.emacs-unstable;
     defaultEditor = true;
     install = true;
    };
    blueman = { enable = true; };
    openssh = { enable = true; };
    upower = { enable = true; };
    fwupd = { enable = true; };
    displayManager = {
      # for some reason the Login keyring doesn't work if autoLogin is enabled
      # autoLogin.enable = true;
      # autoLogin.user = "iammrinal0";
      defaultSession = "none+i3";
    };
    libinput = { enable = true; };
    xserver = import ./services/xserver.nix { inherit pkgs; };
    gvfs = { enable = true; };
    gnome.gnome-keyring.enable = true;
    tailscale.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
    };
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
      emacsConfig = emacsConfig;
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
