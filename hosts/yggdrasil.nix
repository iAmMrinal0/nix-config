# NixOS config for yggdrasil — the homelab services box (Incus VM on TrueNAS).
#
# Deliberately a LEAN, standalone host: it does NOT import ../base.nix (which
# is a desktop/laptop base carrying Wayland/X11, display managers, audio and
# NetworkManager WiFi profiles — none of which a headless Docker host wants).
# App secrets live in the compose repo's gitignored .env files (as on the old
# Pi); sops-nix is wired in directly (not via base.nix) only for the backup
# job's borg passphrase + rclone credentials.
{ config, pkgs, hostname, username, ... }:

{
  imports = [
    ../hardware/${hostname}.nix
    ../modules/nixos/system-label.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;

  networking.hostName = hostname;
  # LAN IP is pinned via a DHCP reservation on the router, so the guest just
  # takes a plain DHCP lease — no interface-name coupling in the config.
  networking.useDHCP = true;

  time.timeZone = "Europe/Stockholm";

  # base.nix normally provides these; a standalone host must set its own.
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" username ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # The reason this host exists. Compose stacks run out of ~/apps.
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Remote admin over Tailscale SSH (ACL-governed), with the key-only sshd
  # below kept as a LAN/console break-glass. extraSetFlags re-asserts `--ssh`
  # on every activation so it survives rebuilds; first boot still needs a
  # one-time `sudo tailscale up` to join + tag the node.
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # nixpkgs defaults KbdInteractiveAuthentication to true — that leaves a
      # PAM password path open despite PasswordAuthentication=false. Close it.
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowAgentForwarding = "no";
      AllowTcpForwarding = "no"; # never a jump host
      MaxAuthTries = 3;
      LogLevel = "VERBOSE"; # logs key fingerprints for audit
      AllowUsers = [ username ];
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2VaKwjYmaBmrbVp14QFZBguI9ah8hC+sw91OYH6bg7 github@mrinalpurohit.in" # betazed
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoWghjXVEMDtNMGjlKyUNXMj8QqaCSTnONn6Y/e66kG cardassia"
    ];
  };
  # No user password is set (key-only login), so give wheel passwordless sudo
  # rather than locking admin out.
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    docker-compose
    rsync
    ncdu
    vim
    borgbackup
    rclone
  ];

  # Services are published over Tailscale (tsdproxy registers its own nodes),
  # so trust the tailscale interface; keep the LAN firewall on otherwise.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
  };

  # --- Secrets (sops) ---
  # The system decrypts these with the host age key derived from the SSH host
  # key. Bootstrap the host into sops FIRST (README "New host bootstrap") or
  # activation can't decrypt. Nothing sensitive lands in the nix store: the
  # borg passphrase and rclone token stay in /run/secrets. rclone reuses the
  # shared gdrive-* secrets, rendered into a root-owned rclone.conf.
  sops = {
    # Scoped file — this host can ONLY decrypt its own 4 secrets, never the
    # shared secrets.yaml (see sops/.sops.yaml creation_rules). Limits blast
    # radius if this container-hosting box is compromised.
    defaultSopsFile = ../sops/yggdrasil.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      "borg-passphrase-${hostname}" = { };
      "rclone-gdrive-client-id" = { };
      "rclone-gdrive-client-secret" = { };
      "rclone-gdrive-token" = { };
      # Full uptime-kuma push URL (incl. token); read at runtime by borgmatic's
      # credential system so the token never enters the nix store.
      "uptime-kuma-borg-push" = { };
    };
    templates."rclone.conf".content = ''
      [gdrive]
      type = drive
      scope = drive.file
      client_id = ${config.sops.placeholder."rclone-gdrive-client-id"}
      client_secret = ${config.sops.placeholder."rclone-gdrive-client-secret"}
      token = ${config.sops.placeholder."rclone-gdrive-token"}
    '';
  };

  # --- Backups: borgmatic → local repo → rclone to Google Drive ---
  # Ports the Pi's borgmatic config natively (github iAmMrinal0/yggdrasil
  # backup/borgmatic/config.yaml): pause running containers → borg create
  # ~/apps → unpause → prune → rclone the encrypted repo to Drive, with
  # borgmatic's uptime_kuma hook pushing start/finish/fail heartbeats. The repo
  # was created by the earlier borg run and is reused (same path + passphrase).
  # unpause is in BOTH after_backup and on_error so a failed backup never
  # leaves containers paused; rclone runs only on success (after_backup).
  services.borgmatic = {
    enable = true;
    settings = {
      source_directories = [ "/home/${username}/apps" ];
      repositories = [{
        path = "/home/${username}/borg-repo";
        label = "local";
      }];
      exclude_patterns = [ "*.pyc" "/home/*/.cache" "*/.vim*.tmp" ];
      encryption_passcommand =
        ''cat ${config.sops.secrets."borg-passphrase-${hostname}".path}'';
      compression = "auto,zstd";
      archive_name_format = "archive-{hostname}-{utcnow}";
      keep_daily = 1;
      keep_weekly = 2;
      keep_monthly = 6;

      # uptime-kuma heartbeats. borgmatic's native uptime_kuma hook can't read
      # the push URL from sops here — this version doesn't interpolate
      # {credential ...} in push_url (it sent the literal string), so we curl
      # the push ourselves, reading the URL from the sops secret at runtime.
      # Mirrors borgmatic's own format exactly: <url>?status=up&msg=<state>
      # (status=down on failure). Reachability to the tailnet URL is confirmed
      # without accept-routes. (before_/after_backup/on_error are deprecated in
      # favour of `commands:` — a future cleanup; they still work.)
      before_backup = [
        ''${config.virtualisation.docker.package}/bin/docker pause $(${config.virtualisation.docker.package}/bin/docker ps -q --filter status=running) || true''
        ''${pkgs.curl}/bin/curl -fsS -m 10 "$(cat ${config.sops.secrets."uptime-kuma-borg-push".path})?status=up&msg=start" || true''
      ];
      # Unpause right after the archive is created — prune/compact/rclone don't
      # need containers paused, so this minimises the pause window.
      after_backup = [
        ''${config.virtualisation.docker.package}/bin/docker unpause $(${config.virtualisation.docker.package}/bin/docker ps -q --filter status=paused) || true''
      ];
      # Mirror to Drive + "finish" push only AFTER compact, i.e. once the repo
      # is in its final committed state. Doing rclone sync in after_backup
      # uploaded the pre-prune/pre-compact repo, so Drive perpetually diverged
      # from local (rclone check always showed differences). compact runs every
      # backup, so this fires reliably and only on success.
      after_compact = [
        ''${pkgs.rclone}/bin/rclone sync /home/${username}/borg-repo gdrive:backups/${hostname} --config ${config.sops.templates."rclone.conf".path}''
        ''${pkgs.curl}/bin/curl -fsS -m 10 "$(cat ${config.sops.secrets."uptime-kuma-borg-push".path})?status=up&msg=finish" || true''
      ];
      on_error = [
        ''${config.virtualisation.docker.package}/bin/docker unpause $(${config.virtualisation.docker.package}/bin/docker ps -q --filter status=paused) || true''
        ''${pkgs.curl}/bin/curl -fsS -m 10 "$(cat ${config.sops.secrets."uptime-kuma-borg-push".path})?status=down&msg=fail" || true''
      ];
    };
  };

  # The upstream borgmatic unit already ships thorough systemd hardening plus
  # ProtectSystem=full (which leaves /home writable, so the repo needs no extra
  # ReadWritePaths). We only reset two of its defaults that don't apply here —
  # an empty assignment resets each directive:
  systemd.services.borgmatic.serviceConfig = {
    # borgmatic's built-in passphrase-credential convention. We read the
    # passphrase via encryption_passcommand (sops) instead, so this credential
    # source never exists → a "couldn't read credential borgmatic.pw" skip
    # warning every run. Drop it.
    LoadCredentialEncrypted = "";
    # The unit's 1-minute pre-start sleep (boot/stagger delay) — pointless on a
    # single box and annoying on manual runs.
    ExecStartPre = "";
  };

  system.stateVersion = "26.05";
}
