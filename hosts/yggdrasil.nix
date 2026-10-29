# NixOS config for yggdrasil — the homelab services box (VM on TrueNAS).
#
# Deliberately a LEAN, standalone host: it does NOT import ../base.nix (which
# is a desktop/laptop base carrying Wayland/X11, display managers, audio and
# NetworkManager WiFi profiles — none of which a headless Docker host wants).
# App secrets live in the compose repo's gitignored .env files (as on the old
# Pi); sops-nix is wired in directly (not via base.nix) only for the backup
# job's borg passphrase + rclone credentials.
{ config, pkgs, inputs, hostname, username, ... }:

{
  imports = [
    ../hardware/${hostname}.nix
    ../modules/nixos/system-label.nix
    # Headless shell niceties (zsh + atuin + tmux + CLI tools), enabled below.
    ../modules/nixos/server-profile.nix
    # `comma` (,) to run any tool once without installing it, backed by the
    # prebuilt nix-index database (no local `nix-index` run needed).
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # `,` <cmd> runs a program from nixpkgs without adding it to systemPackages —
  # handy on a server for one-off tools. Uses the flake's prebuilt index.
  programs.nix-index-database.comma.enable = true;

  # Login shell + interactive tooling for operating the box over SSH.
  modules.server.enable = true;
  # Boot a tmux session rooted at the compose repo (~/apps, the folder name is
  # kept even though the repo is "yggdrasil") so `tmux attach` drops straight
  # into where the docker stacks are managed.
  modules.server.tmux = {
    sessionName = "apps";
    workingDir = "/home/${username}/apps";
  };

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
    # Daily rather than weekly so the store is trimmed a little at a time
    # instead of in one big sweep; the randomized delay keeps it from landing
    # exactly on top of the nightly backup job.
    gc = {
      automatic = true;
      dates = "daily";
      randomizedDelaySec = "14m";
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
    # Default bind for a published port that names no host address. A bare
    # "8080:80" then lands on loopback (fails closed); a port meant for the
    # tailnet says "0.0.0.0:" and is filtered by the DOCKER-USER rule below.
    daemon.settings.ip = "127.0.0.1";
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
      # ON deliberately: git in ~/apps pushes to GitHub with the agent
      # forwarded from the laptop, so no private key ever sits on this box —
      # lose the VM and there is nothing to revoke. The cost is that while a
      # session is open, whoever can read the forwarded socket (root, and us)
      # can authenticate as us; `ssh-add -c` on the laptop turns that into a
      # per-use confirmation if it ever matters. Unrelated to
      # AllowTcpForwarding, which stays off — agent forwarding is its own
      # channel type, not a TCP tunnel.
      AllowAgentForwarding = "yes";
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

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    git
    docker-compose
    rsync
    ncdu
    vim
    borgbackup
    rclone
    sqlite # sqlite3 CLI for poking the apps' databases (vaultwarden, etc.)
    jq # compose/docker/tailscale all speak JSON; wanted often enough to install
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    openssl
  ];

  # Git identity for committing in ~/apps. No home-manager on this host, so
  # this renders a system-wide /etc/gitconfig; the identity is imported from
  # the same file as modules/home-manager/git.nix so the two can't drift.
  # Commits made on the VM are unsigned — the signing key stays on the
  # laptops; push auth comes from the forwarded agent (Tailscale SSH).
  programs.git = {
    enable = true;
    config = {
      user = import ../modules/git-identity.nix;
    };
  };

  # Services are published over Tailscale (tsdproxy registers its own nodes),
  # so trust the tailscale interface; keep the LAN firewall on otherwise.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    # Docker-published ports never reach nixos-fw: dockerd DNATs them in nat
    # PREROUTING, so they arrive as FORWARD traffic, not INPUT. Binding them
    # to the tailnet address was no boundary either, since the DNAT matches on
    # destination only and a LAN host routing that address via this box got
    # in. So filter in DOCKER-USER, which dockerd only creates when missing
    # and never flushes (it survives docker restarts): a new connection into
    # a container bridge is accepted only from tailscale0 or from another
    # container. Compose can then publish tailnet ports on 0.0.0.0.
    #
    # Idempotent, and deliberately no extraStopCommands: firewall-reload runs
    # those before the start script, which would leave FORWARD open while it
    # runs.
    extraCommands = ''
      ip46tables -N DOCKER-USER 2>/dev/null || true
      ip46tables -N docker-ingress 2>/dev/null || ip46tables -F docker-ingress
      ip46tables -A docker-ingress -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
      ip46tables -A docker-ingress -i tailscale0 -j RETURN
      ip46tables -A docker-ingress -i br-+ -j RETURN
      ip46tables -A docker-ingress -i docker0 -j RETURN
      # Mullvad exit node (gluetun/nyc): direct WireGuard from LAN peers.
      ip46tables -A docker-ingress -p udp -m conntrack --ctorigdstport 41642 -j RETURN
      ip46tables -A docker-ingress -j DROP
      for out in br-+ docker0; do
        ip46tables -C DOCKER-USER -o "$out" -j docker-ingress 2>/dev/null \
          || ip46tables -I DOCKER-USER -o "$out" -j docker-ingress
      done
    '';
  };

  # --- Secrets (sops) ---
  # The system decrypts these with the host age key derived from the SSH host
  # key. Bootstrap the host into sops FIRST (README "New host bootstrap") or
  # activation can't decrypt. Nothing sensitive lands in the nix store: the
  # borg passphrase and rclone token stay in /run/secrets. rclone reuses the
  # shared gdrive-* secrets, rendered into a root-owned rclone.conf.
  sops = {
    # Scoped file — this host can ONLY decrypt its own secrets, never the
    # shared secrets.yaml (see .sops.yaml creation_rules at the repo root).
    # Limits blast radius if this container-hosting box is compromised.
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
      # Separate monitor for the weekly Drive verification (borg-drive-check).
      "uptime-kuma-borg-drive-push" = { };
      # Origin of the OIDC issuer (scheme + host, no trailing slash), e.g.
      # https://<name>.<tailnet>.ts.net — read at runtime by idp-ready. Not
      # secret in the credential sense; it lives here because this repo is
      # public and the URL names both the tailnet and the IdP in use.
      "oidc-issuer-url" = { };
      # memory-alpha-pull (below): the app server's address, login user and
      # host key, kept here because this repo is public (its SSH key is
      # generated on the box, not stored in sops). The push URL is its own
      # uptime-kuma monitor so a stalled pull is visible separately from
      # borgmatic.
      "memory-alpha-host" = { };
      "memory-alpha-user" = { };
      "memory-alpha-host-key" = { };
      "uptime-kuma-memory-alpha-push" = { owner = username; };
    };
    templates."rclone.conf".content = ''
      [gdrive]
      type = drive
      scope = drive.file
      client_id = ${config.sops.placeholder."rclone-gdrive-client-id"}
      client_secret = ${config.sops.placeholder."rclone-gdrive-client-secret"}
      token = ${config.sops.placeholder."rclone-gdrive-token"}
    '';
    templates."memory-alpha-known-hosts" = {
      owner = username;
      content = ''
        ${config.sops.placeholder."memory-alpha-host"} ${config.sops.placeholder."memory-alpha-host-key"}
      '';
    };
    templates."memory-alpha-ssh-config" = {
      owner = username;
      content = ''
        Host memory-alpha
          HostName ${config.sops.placeholder."memory-alpha-host"}
          User ${config.sops.placeholder."memory-alpha-user"}
          IdentityFile /var/lib/memory-alpha/id_ed25519
          IdentitiesOnly yes
          UserKnownHostsFile ${config.sops.templates."memory-alpha-known-hosts".path}
          StrictHostKeyChecking yes
          BatchMode yes
          ConnectTimeout 30
      '';
    };
  };

  # --- Backups: borgmatic → local repo → rclone to Google Drive ---
  # Ports the Pi's borgmatic config natively (github iAmMrinal0/yggdrasil
  # backup/borgmatic/config.yaml): pause running containers → borg create
  # ~/apps → unpause → prune → compact → rclone the encrypted repo to Drive,
  # with uptime-kuma start/finish/fail heartbeats. The repo was created by the
  # earlier borg run and is reused (same path + passphrase). unpause runs after
  # create AND on error so a failed backup never leaves containers paused;
  # rclone runs only after a successful compact.
  services.borgmatic = {
    enable = true;
    settings = {
      source_directories = [
        "/home/${username}/apps"
        # Staged nightly by memory-alpha-pull below.
        "/home/${username}/backups/memory-alpha"
      ];
      repositories = [{
        path = "/home/${username}/borg-repo";
        label = "local";
      }];
      exclude_patterns = [ "*.pyc" "/home/*/.cache" "*/.vim*.tmp" ];
      encryption_passcommand =
        ''cat ${config.sops.secrets."borg-passphrase-${hostname}".path}'';
      compression = "auto,zstd";
      archive_name_format = "archive-{hostname}-{utcnow}";
      # A week of daily points, not one: keep_daily = 1 meant the only archive
      # newer than a week was last night's, so any corruption or bad app write
      # not caught the same day left nothing to fall back to but a week-old
      # archive. Cheap in practice — borg dedups, and these stacks' data is
      # mostly static between runs.
      keep_daily = 7;
      keep_weekly = 2;
      keep_monthly = 6;

      # uptime-kuma heartbeats. borgmatic's native uptime_kuma hook can't read
      # the push URL from sops here — this version doesn't interpolate
      # {credential ...} in push_url (it sent the literal string), so we curl
      # the push ourselves, reading the URL from the sops secret at runtime.
      # Mirrors borgmatic's own format exactly: <url>?status=up&msg=<state>
      # (status=down on failure). Reachability to the tailnet URL is confirmed
      # without accept-routes.
      #
      # `after` hooks fire on success AND failure unless `states` narrows them,
      # so anything that must only follow a good run says `states = [ "finish" ]`.
      commands =
        let
          docker = "${config.virtualisation.docker.package}/bin/docker";
          kuma = status: msg:
            ''${pkgs.curl}/bin/curl -fsS -m 10 "$(cat ${config.sops.secrets."uptime-kuma-borg-push".path})?status=${status}&msg=${msg}" || true'';
          unpause = "${docker} unpause $(${docker} ps -q --filter status=paused) || true";
        in
        [
          {
            before = "action";
            when = [ "create" ];
            run = [
              "${docker} pause $(${docker} ps -q --filter status=running) || true"
              (kuma "up" "start")
            ];
          }
          # Unpause right after the archive is created, whether or not create
          # succeeded — prune/compact/rclone don't need containers paused, so
          # this minimises the pause window.
          {
            after = "action";
            when = [ "create" ];
            run = [ unpause ];
          }
          # Mirror to Drive + "finish" push only AFTER a successful compact, i.e.
          # once the repo is in its final committed state. Doing rclone sync
          # right after create uploaded the pre-prune/pre-compact repo, so Drive
          # perpetually diverged from local (rclone check always showed
          # differences). compact runs every backup, so this fires reliably.
          {
            after = "action";
            when = [ "compact" ];
            states = [ "finish" ];
            run = [
              "${pkgs.rclone}/bin/rclone sync /home/${username}/borg-repo gdrive:backups/${hostname} --config ${config.sops.templates."rclone.conf".path}"
              (kuma "up" "finish")
            ];
          }
          # Unpause again in case the failure was in the pause hook itself
          # (before create ran, so the unpause above never fired). `when` keeps
          # this to the backup actions, like the old on_error: without it a
          # failed manual `borgmatic extract`/`list` paged as a failed backup.
          {
            after = "error";
            when = [ "create" "prune" "compact" "check" ];
            run = [ unpause (kuma "down" "fail") ];
          }
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

  # --- Weekly: verify the Drive copy byte-for-byte against the local repo ---
  # rclone sync already checks each upload's hash, but only Drive's *stored*
  # MD5 — never the bytes Drive actually serves back. --download streams every
  # file (~repo size, nothing written to disk) and compares it with local, so
  # a match plus borgmatic's monthly check on the local repo means the offsite
  # copy is restorable. Read-only on both sides. Midday, well clear of the
  # nightly run; if borgmatic is running anyway (Persistent catch-up after
  # downtime), wait for it so a half-synced repo isn't reported as drift.
  # Weekly rather than monthly: uptime-kuma caps push intervals at ~24 days.
  systemd.services.borg-drive-check = {
    description = "Verify the Google Drive borg copy matches the local repo";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "6h";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -euo pipefail
      push="$(cat ${config.sops.secrets."uptime-kuma-borg-drive-push".path})"
      trap '${pkgs.curl}/bin/curl -fsS -m 10 -o /dev/null "$push?status=down&msg=fail" || true' ERR
      while ${pkgs.systemd}/bin/systemctl is-active -q borgmatic.service; do
        echo "borgmatic is running, waiting"
        sleep 60
      done
      ${pkgs.rclone}/bin/rclone check --download \
        /home/${username}/borg-repo gdrive:backups/${hostname} \
        --config ${config.sops.templates."rclone.conf".path}
      ${pkgs.curl}/bin/curl -fsS -m 10 -o /dev/null "$push?status=up&msg=OK" || true
    '';
  };
  systemd.timers.borg-drive-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 12:00:00";
      Persistent = true;
    };
  };

  # --- memory-alpha: pull from its app server, then borg takes it ---
  # Replaces a manual backup flow that committed every image and db revision
  # to a git repo forever and only ran when remembered. This just stages a
  # current copy under ~/backups; versioning, retention, encryption and the
  # offsite copy are borgmatic's. The sqlite db is snapshotted server-side
  # with `.backup` (rsync-ing the live file can catch it mid-write) and
  # integrity-checked before it replaces the previous copy, so a bad pull
  # never overwrites a good one. Images are rsynced without --delete, so a
  # file removed on the server stays here. Runs ahead of borgmatic's nightly
  # run; Persistent catches up after downtime.
  #
  # Its SSH key is a dedicated one made by hand on the box (the forwarded agent
  # isn't around at 23:30, and the host key doubles as the sops age identity):
  #   ssh-keygen -t ed25519 -N "" -C yggdrasil-memory-alpha-backup \
  #     -f /var/lib/memory-alpha/id_ed25519
  # The private half never leaves /var/lib; the app server pins the public half
  # to a read-only forced command that exposes only `snapshot` and read-only
  # rsync of `db/` and `images/`. Rebuilt VM → make a new key and swap the one
  # authorized_keys line.
  systemd.services.memory-alpha-pull = {
    description = "Pull memory-alpha sqlite snapshot + images for borgmatic";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "borgmatic.service" ];
    path = with pkgs; [ openssh rsync sqlite curl coreutils ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      TimeoutStartSec = "1h";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -euo pipefail
      dest=/home/${username}/backups/memory-alpha
      ssh="ssh -F ${config.sops.templates."memory-alpha-ssh-config".path}"
      push="$(cat ${config.sops.secrets."uptime-kuma-memory-alpha-push".path})"
      trap 'curl -fsS -m 10 -o /dev/null "$push?status=down&msg=fail" || true' ERR
      mkdir -p "$dest/db" "$dest/images"

      # The snapshot dir is pulled whole, so this never names the db file.
      # It lands in an empty db.new and replaces db only once every file in
      # it passes sqlite's integrity check.
      $ssh memory-alpha snapshot
      rm -rf "$dest/db.new" "$dest/db.old"
      mkdir "$dest/db.new"
      rsync -a -e "$ssh" memory-alpha:db/ "$dest/db.new/"
      n=0
      for f in "$dest/db.new"/*; do
        [ -f "$f" ] || continue
        check="$(sqlite3 "$f" 'PRAGMA integrity_check')"
        if [ "$check" != ok ]; then
          echo "integrity_check failed on $f, keeping previous copy: $check" >&2
          false
        fi
        n=$((n + 1))
      done
      if [ "$n" -eq 0 ]; then
        echo "snapshot dir is empty, keeping previous copy" >&2
        false
      fi
      mv "$dest/db" "$dest/db.old"
      mv "$dest/db.new" "$dest/db"
      rm -rf "$dest/db.old"

      # The images are flat files; the server keeps its in-progress work in
      # subfolders, which are skipped.
      rsync -a --partial --stats --exclude='*/' \
        -e "$ssh" memory-alpha:images/ "$dest/images/"

      curl -fsS -m 10 -o /dev/null "$push?status=up&msg=OK" || true
    '';
  };
  systemd.timers.memory-alpha-pull = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 23:30:00";
      Persistent = true;
    };
  };

  # --- Boot ordering for the OIDC client stacks ---
  # Every compose stack in ~/apps carries `restart: unless-stopped`, so after a
  # reboot it is *dockerd* — not compose — that starts the containers, and
  # dockerd knows nothing about compose's `depends_on` (that is a compose-CLI
  # construct applied only at `up` time). Container start order on boot is
  # therefore arbitrary, and no amount of depends_on / priority / merging the
  # per-app directories into one project can change that.
  #
  # The apps that authenticate against the IdP fetch its OIDC discovery
  # document ONCE at process startup and cache the result — a failed fetch is
  # never retried, so they come up with auth broken and stay that way until
  # restarted. The precondition is not merely "the IdP container is running"
  # either: the issuer is a tsnet node published by tsdproxy (its URL is a sops
  # secret — this repo is public, and the URL names both the tailnet and which
  # IdP is in use), so the real chain is tailscaled → tsdproxy → the issuer node
  # registered with a TLS cert → the IdP healthy. That is a readiness *probe*,
  # not an ordering constraint, which is why this gates on the discovery
  # endpoint answering rather than on a unit ordering edge or a fixed sleep.
  #
  # Nothing here manages the containers: dockerd still owns their lifecycle and
  # `docker compose` is still the interface. These units only add a one-shot
  # correction pass that lets the race happen and then converges to the right
  # state — far simpler than making ~26 independent compose projects order
  # themselves. `systemctl restart oidc-clients-reconcile` is the manual fix too.
  systemd.services.idp-ready = {
    description = "Gate: wait for the OIDC discovery document to answer";
    after = [ "docker.service" "tailscaled.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    # Pulled in as a dependency of oidc-clients-reconcile below, so no wantedBy.
    # A rebuild that edits these units shouldn't bounce the apps as a side
    # effect — this only ever needs to run at boot, or by hand.
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # A cold boot has to bring tailscaled up and let tsdproxy register (or
      # renew the cert for) the `auth` node before this can ever succeed. On
      # timeout the reconcile below is skipped via Requires= — restarting apps
      # against an issuer that never came up would fix nothing.
      TimeoutStartSec = "10min";
    };
    # Same approach as the borgmatic uptime-kuma hooks: curl a tailnet name
    # directly from the host (works without accept-routes), with the URL read
    # from sops at RUNTIME so the tailnet name never enters the nix store or
    # this public repo. The secret holds the issuer origin only; the
    # discovery path is a spec constant and stays visible here.
    script = ''
      url="$(cat ${
        config.sops.secrets."oidc-issuer-url".path
      })/.well-known/openid-configuration"
      until ${pkgs.curl}/bin/curl -fsS -m 10 -o /dev/null "$url"; do
        echo "issuer not ready, retrying in 10s"
        sleep 10
      done
      echo "issuer ready"
    '';
  };

  systemd.services.oidc-clients-reconcile = {
    description = "Restart the OIDC client stacks once the issuer is reachable";
    after = [ "idp-ready.service" ];
    requires = [ "idp-ready.service" ];
    wantedBy = [ "multi-user.target" ];
    restartIfChanged = false;
    # RemainAfterExit keeps it "active" after the boot run. Without it every
    # `nixos-rebuild switch` started it again (an inactive unit wanted by
    # multi-user.target), restarting all the OIDC apps on each deploy; their
    # tsdproxy nodes being rebuilt at once once pinned tsdproxy at its memory
    # cap. restartIfChanged above only covers edits to this unit.
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Driven by an `oidc.client=true` compose label rather than a list of names
    # kept in sync by hand — a new app that reads the issuer at startup only has
    # to carry the label to be covered here, and this unit never needs editing.
    # Plain `docker restart` rather than `docker compose restart` so the unit
    # needs no compose file, .env or working directory: the containers already
    # exist by the time this runs and only their processes need recycling.
    script = ''
      docker=${config.virtualisation.docker.package}/bin/docker
      names="$($docker ps --filter label=oidc.client=true --format '{{.Names}}')"
      if [ -z "$names" ]; then
        # Not an error worth failing the unit over, but it does mean either the
        # labels went missing or nothing is up yet — say so rather than exiting
        # silently as if the work were done.
        echo "no running containers labelled oidc.client=true — nothing to reconcile" >&2
        exit 0
      fi
      for c in $names; do
        echo "restarting $c"
        $docker restart "$c" || true
      done
    '';
  };

  system.stateVersion = "26.05";
}
