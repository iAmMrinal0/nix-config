{ lib, config, inputs, pkgs, username, hostname, ... }:

let
  secrets = [
    "service-access-host"
    "service-access-key"
    "nixpkgs-review"
    "kronor-openvpn-staging"
    "kronor-openvpn-production"
    "bw-session-key"
    "cachix-auth-token"
    "atuin-key"
    "wifi-env"
    # Private ssh host blocks (homelab/cloud IPs + usernames), Include'd
    # from the HM-managed ~/.ssh/config (modules/home-manager/ssh.nix)
    "ssh-config-private"
    # rclone gdrive OAuth fields, injected into ~/.config/rclone/rclone.conf
    # by programs.rclone (modules/home-manager/rclone.nix). User-readable
    # (defaultPermissions) since rclone-config.service runs as the user.
    "rclone-gdrive-client-id"
    "rclone-gdrive-client-secret"
    "rclone-gdrive-token"
  ];
  defaultPermissions = secret: {
    ${secret} = {
      mode = "0440";
      owner = config.users.users.${username}.name;
      group = config.users.users.${username}.group;
    };
  };

in {

  sops = {
    defaultSopsFile = ./sops/secrets.yaml;
    # The root of trust: each host's age key is derived from its SSH host
    # key. This is the sops-nix default, made explicit so the dependency is
    # visible — no secrets decrypt without this key, and a new host must be
    # bootstrapped into sops/.sops.yaml first (see README "New host
    # bootstrap"). Under impermanence this becomes /persist/etc/ssh/....
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets =
      lib.foldl' lib.mergeAttrs { } (builtins.map defaultPermissions secrets)
      // {
        # Decrypted into /run/secrets-for-users *before* users are created,
        # so it can't carry the user-owned defaultPermissions the secrets
        # above use — hence declared separately. Per-host key so each
        # machine has its own password.
        "user-password-${hostname}".neededForUsers = true;
      };
  };

  nixpkgs.config = {
    allowUnfree = true;
    chromium = { enableWideVine = true; };
    permittedInsecurePackages = [
      "xpdf-4.06"
      # Pulled in by bitwarden-desktop (an Electron app). 26.05 ships a
      # bundled Electron that upstream has marked EOL; nothing in our
      # config can bump it independently, so allow it until bitwarden-
      # desktop in nixpkgs moves to a supported Electron. Bump this string
      # when the bundled version changes.
      "electron-39.8.10"
    ];
  };

  nix = {
    package = pkgs.nixVersions.latest;
    # Drop the default NIX_PATH entry for root's channels (doesn't exist on a
    # flake-based system, causing "does not exist, ignoring" warnings) and
    # resolve nixpkgs through the registry instead, pinned to the flake input
    # so legacy tools (nix-shell -p, comma, …) use the system's nixpkgs.
    nixPath = [ "nixpkgs=flake:nixpkgs" ];
    registry.nixpkgs.flake = inputs.nixpkgs;
    extraOptions = ''
      experimental-features = nix-command flakes ca-derivations
      keep-outputs = true
      keep-derivations = true
    '';
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" config.users.users.${username}.name ];
    };
  };

  programs.nh = {
    enable = true;
    flake = "${config.users.users.${username}.home}/nix-config";
  };

  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  environment = {
    systemPackages = [
      pkgs.atop
      pkgs.android-file-transfer
      pkgs.binutils
      pkgs.docker-compose
      pkgs.git
      pkgs.libsecret
      pkgs.ncdu
      pkgs.nix-build-uncached
      pkgs.ntfs3g
      pkgs.openjdk
      pkgs.openssl
      pkgs.pptp
      pkgs.sops
      pkgs.stow
      pkgs.tcpdump
      pkgs.traceroute
      pkgs.usbutils
      pkgs.v4l-utils
      pkgs.vim
      pkgs.yubikey-personalization
      pkgs.bitwarden-desktop
      pkgs.kdePackages.kdenlive
      pkgs.cryptomator
      pkgs.nfs-utils
      pkgs.bitwarden-cli
      pkgs.xpdf
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
      (pkgs.writeShellApplication {
        name = "connect-kronor-vpn";
        runtimeInputs = [ pkgs.openvpn pkgs.bitwarden-cli ];
        text = ''
          echo "mrinal@kronor.io" > /tmp/kronor_vpn.pass

          if [[ "''${1:-staging}" == "staging" ]]; then
              bw get totp "pritunl staging" --session "$(cat ${config.sops.secrets.bw-session-key.path})" >> /tmp/kronor_vpn.pass
              sudo openvpn --config ${config.sops.secrets.kronor-openvpn-staging.path} --auth-user-pass /tmp/kronor_vpn.pass --auth-nocache
          elif [[ "$1" == "production" ]]; then
              bw get totp "pritunl prod" --session "$(cat ${config.sops.secrets.bw-session-key.path})" >> /tmp/kronor_vpn.pass
              sudo openvpn --config ${config.sops.secrets.kronor-openvpn-production.path} --auth-user-pass /tmp/kronor_vpn.pass --auth-nocache
          fi
        '';
      })
    ];
    # Qt style is now configured per-session via the home-manager qt module
    # (modules/home-manager/qt.nix → Adwaita-Dark) and re-asserted at the
    # system level for sway-exec'd apps via the NixOS qt module
    # (modules/nixos/wayland-session.nix → qt.style = "adwaita-dark", which
    # writes QT_STYLE_OVERRIDE into /etc/pam/environment). The previous
    # `QT_STYLE_OVERRIDE = "gtk2"` here loaded qtstyleplugins-style-gtk2 for
    # Qt5 apps, but that plugin doesn't exist for Qt6 — KF6 apps saw it,
    # rejected it as "invalid style override", and fell back to Fusion.
    variables = { };
  };

  security.pam.services.lightdm.enableGnomeKeyring = true;
  # Same unlock for TTY logins (the `login` PAM service), so the keyring —
  # and with it the gcr ssh-agent's stored passphrases — is available
  # without a GUI session.
  security.pam.services.login.enableGnomeKeyring = true;
  security.rtkit.enable = true;
  # fwupd-refresh.service (timer-driven LVFS metadata refresh) runs as a
  # sessionless DynamicUser; the refresh-remote polkit action defaults to
  # allow_inactive=no, so the unit fails with "Failed to obtain auth".
  # Allow exactly that action for exactly that user.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.fwupd.refresh-remote" &&
          subject.user == "fwupd-refresh") {
        return polkit.Result.YES;
      }
    });

    /* logind power actions default to allow_inactive=auth_admin_keep, and
       with two seat sessions alive (i3 on lightdm + a TTY compositor —
       routine during the sway migration) the caller's session can be
       flagged inactive: systemctl reboot then blocks forever on a polkit
       auth dialog that never reaches the user (rofi-power-menu swallows
       stderr), the user logs out thinking it's broken, and the lingering
       session makes the lightdm greeter grey out its power buttons
       (CanReboot=challenge). Allow wheel to manage power unconditionally —
       no auth, nothing to hang on, regardless of session active-state. */
    polkit.addRule(function(action, subject) {
      var powerActions = [
        "org.freedesktop.login1.reboot",
        "org.freedesktop.login1.reboot-multiple-sessions",
        "org.freedesktop.login1.power-off",
        "org.freedesktop.login1.power-off-multiple-sessions",
        "org.freedesktop.login1.suspend",
        "org.freedesktop.login1.suspend-multiple-sessions",
        "org.freedesktop.login1.hibernate",
        "org.freedesktop.login1.hibernate-multiple-sessions"
      ];
      if (powerActions.indexOf(action.id) !== -1 &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
      };
    };
    # brightnessctl replaces the removed programs.light/pkgs.light (26.05).
    # Its udev rules chgrp the backlight sysfs nodes to `video` + add group
    # write, granting access without setuid (the user is in `video`). Same
    # access model programs.light had; also what the i3 brightness
    # keybinds rely on. The package must be registered with udev for the
    # rules to apply — installing it to PATH alone wouldn't.
    udev.packages = [ pkgs.yubikey-personalization pkgs.brightnessctl ];
    davfs2.enable = true;
    colord.enable = true;
    dbus.packages = [
      pkgs.blueman
      pkgs.gcr
      pkgs.seahorse
    ];
    dnsmasq = { enable = true; };
    geoclue2.enable = true;
    openssh = { enable = true; };
    upower = { enable = true; };
    fwupd = { enable = true; };
    libinput = { enable = true; };
    gvfs = { enable = true; };
    gnome.gnome-keyring.enable = true;
    # The ssh-agent: auto-discovers keys in ~/.ssh, stores their
    # passphrases in the keyring on first use, and serves them in every
    # later session once PAM unlocks the keyring at login (GUI or TTY).
    # Replaces Bitwarden as the default agent (manual GUI unlock, no TTY);
    # Bitwarden's own agent socket stays available via
    # BITWARDEN_SSH_AUTH_SOCK (modules/home/home.nix) for vault-held keys.
    gnome.gcr-ssh-agent.enable = true;
  };

  programs = {
    # gcr-ssh-agent is the agent now; its module asserts this is off
    # (only one agent can own the socket).
    ssh.startAgent = false;
    zsh = { enable = true; };
    seahorse = { enable = true; };
  };

  modules = {
    audio.enable = true;

    bluetooth.enable = true;

    boot.enable = true;

    displayManager.enable = true;

    docker.enable = true;

    fonts.enable = true;

    networking = {
      enable = true;
      networkManager = {
        enable = true;
        wifi = {
          macAddressRandomization = "random";
          # SSIDs and PSKs both come from the wifi-env sops secret via
          # $VAR substitution, so neither is visible in the repo.
          profiles = {
            home = {
              connection = {
                id = "home";
                type = "wifi";
              };
              wifi.ssid = "$WIFI_HOME_SSID";
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$WIFI_HOME_PSK";
              };
            };
            home-5ghz = {
              connection = {
                id = "home-5ghz";
                type = "wifi";
              };
              wifi.ssid = "$WIFI_HOME_5GHZ_SSID";
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$WIFI_HOME_PSK";
              };
            };
            fika = {
              connection = {
                id = "fika";
                type = "wifi";
              };
              wifi.ssid = "$WIFI_FIKA_SSID";
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$WIFI_FIKA_PSK";
              };
            };
            office-guest = {
              connection = {
                id = "office-guest";
                type = "wifi";
              };
              wifi.ssid = "$WIFI_OFFICE_GUEST_SSID";
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$WIFI_OFFICE_GUEST_PSK";
              };
            };
          };
        };
      };
      firewall = { enable = true; };
      extraHosts = ''
        127.0.0.1 avarda.local
        127.0.0.1 bankid.local
        127.0.0.1 swish.local
        127.0.0.1 mss.swish.local
        127.0.0.1 status.swish.local
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
        127.0.0.1 trustly.local
      '';
    };

    openrazer.enable = true;
    printing.enable = true;
    tailscale.enable = true;
    touchegg.enable = true;
    xserver.enable = true;
    # Phase 1 of i3 → SwayFX migration. `enable` installs Wayland userspace
    # tools (swayfx, kanshi, grim, etc.) without touching lightdm's session
    # list — safe to switch into without rebooting.
    # `registerSession` registers sway as a login session, sets up xdg-portal
    # and PAM for swaylock; flipping this requires `systemctl restart
    # display-manager` or a reboot BEFORE logging out (see
    # modules/nixos/wayland-session.nix for why).
    wayland = {
      enable = true;
      # registerSession defaults to false here — that's the lightdm + i3
      # recovery generation. Each host opts into the greetd picker in its
      # own file (both betazed and mordor now set it true). mkDefault lets
      # the host file override without needing mkForce there.
      registerSession = lib.mkDefault false;
    };
    editors.vscode.enable = true;

    memorySafeguards.enable = true;
  };

  # Passwords are declarative: the yescrypt hash lives in sops
  # (user-password-<hostname>, one per machine), so `passwd` changes are
  # reverted on rebuild — rotate by updating the secret instead. Root has
  # no declared password and is therefore locked; recovery/admin goes
  # through sudo (wheel).
  users.mutableUsers = false;
  users.users.${username} = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."user-password-${hostname}".path;
    extraGroups = [
      # "adbusers" dropped: programs.adb (which created this group) was
      # removed in 26.05; systemd 258 grants adb device access via uaccess,
      # so the group is gone and listing it would warn.
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

  zramSwap.enable = true;

  # for mounting NFS shares
  boot.supportedFilesystems = [ "nfs" ];
}
