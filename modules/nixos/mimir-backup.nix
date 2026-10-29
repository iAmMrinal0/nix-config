# A directory kept twice over, every 15 minutes:
#
#  - history: a local git repository (its .git kept outside the directory).
#  - mirror: the same files, each encrypted with age to `recipients`, pushed
#    to a private GitHub repository. This host has only the public keys, so
#    it can write the mirror but not read it.
#
# The mirror's remote and deploy key are set up once by hand:
#   ssh-keygen -f /var/lib/mimir-backup/deploy_key  (add the .pub as a deploy key)
#   git -C /var/lib/mimir-backup/mirror remote add origin git@github.com:<owner>/<repo>.git
{ config, lib, pkgs, ... }:

let
  cfg = config.services.mimir-backup;

  backup = pkgs.writeShellApplication {
    name = "mimir-backup";
    runtimeInputs = with pkgs; [ git age openssh coreutils gnused ];
    text = ''
      src=${lib.escapeShellArg cfg.dir}
      state=${lib.escapeShellArg cfg.stateDir}
      recipients=(${lib.concatMapStringsSep " " (r: "-r ${lib.escapeShellArg r}") cfg.recipients})
      history="$state/history.git"
      mirror="$state/mirror"
      hashes="$state/hashes"
      export GIT_AUTHOR_NAME="mimir backup" GIT_AUTHOR_EMAIL="mimir@localhost"
      export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
      export GIT_SSH_COMMAND="ssh -i $state/deploy_key -o IdentitiesOnly=yes -o BatchMode=yes"

      h() { git --git-dir="$history" --work-tree="$src" "$@"; }

      # ---- history
      if [ ! -d "$history" ]; then
        git init --quiet --bare "$history"
        git --git-dir="$history" config core.bare false
        git --git-dir="$history" config core.quotePath false
        printf '%s\n' '.obsidian/workspace.json' '.obsidian/workspace-mobile.json' '.trash/' '.DS_Store' > "$history/info/exclude"
      fi
      h add --all
      if ! h diff --cached --quiet 2>/dev/null || ! h rev-parse --quiet --verify HEAD >/dev/null; then
        changed=$(h diff --cached --name-only | wc -l)
        h commit --quiet --allow-empty -m "$changed files changed"
      fi

      # ---- mirror: re-encrypt only what changed since the last run
      if [ ! -d "$mirror/.git" ]; then
        git init --quiet -b main "$mirror"
        printf '%s\n' '*.age diff=age' > "$mirror/.gitattributes"
        cat > "$mirror/README.md" <<'EOF'
      Each file is encrypted with age.

      Readable diffs on a machine with the key:

          git config diff.age.textconv "age -d -i ~/.config/sops/age/keys.txt"
          git log -p

      Restore a file: age -d -i ~/.config/sops/age/keys.txt -o file file.age
      EOF
      fi
      touch "$hashes"
      declare -A old=()
      while IFS=$'\t' read -r sum path; do old["$path"]=$sum; done < "$hashes"
      declare -A now=()
      : > "$hashes.new"
      while IFS= read -r -d "" path; do
        sum=$(sha256sum "$src/$path" | cut -d' ' -f1)
        now["$path"]=1
        printf '%s\t%s\n' "$sum" "$path" >> "$hashes.new"
        if [ "''${old[$path]:-}" != "$sum" ] || [ ! -f "$mirror/$path.age" ]; then
          mkdir -p "$(dirname "$mirror/$path")"
          rm -f "$mirror/$path.age"
          age "''${recipients[@]}" -o "$mirror/$path.age" "$src/$path"
        fi
      done < <(h ls-files -z)
      for path in "''${!old[@]}"; do
        if [ -z "''${now[$path]:-}" ]; then rm -f "$mirror/$path.age"; fi
      done
      mv "$hashes.new" "$hashes"

      git -C "$mirror" add --all
      if ! git -C "$mirror" diff --cached --quiet || ! git -C "$mirror" rev-parse --quiet --verify HEAD >/dev/null; then
        changed=$(git -C "$mirror" diff --cached --name-only | wc -l)
        git -C "$mirror" commit --quiet -m "$changed files changed"
      fi
      # Pushed only once a remote is set up (see the top of this file).
      if git -C "$mirror" remote get-url origin >/dev/null 2>&1; then
        # Refuse to push anything that is not age-encrypted.
        bad=$(git -C "$mirror" ls-files -z | while IFS= read -r -d "" f; do
          case "$f" in .gitattributes|README.md) continue ;; esac
          head -c 22 "$mirror/$f" | grep -q '^age-encryption.org/v1' || printf '%s\n' "$f"
        done)
        if [ -n "$bad" ]; then
          echo "refusing to push: not encrypted:" >&2
          echo "$bad" >&2
          exit 1
        fi
        git -C "$mirror" push --quiet origin main
      fi
    '';
  };
in
{
  options.services.mimir-backup = {
    enable = lib.mkEnableOption "a local history and encrypted off-site mirror of a directory";
    dir = lib.mkOption { type = lib.types.str; description = "The directory to back up."; };
    user = lib.mkOption { type = lib.types.str; description = "Owner of the directory; the job runs as this user."; };
    recipients = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      description = "age public keys the mirror is encrypted to; any one of them opens it.";
    };
    stateDir = lib.mkOption { type = lib.types.str; default = "/var/lib/mimir-backup"; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ backup pkgs.age ];

    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0700 ${cfg.user} users -" ];

    systemd.services.mimir-backup = {
      description = "Commit the history and push the encrypted mirror";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = "${backup}/bin/mimir-backup";
        Nice = 10;
        ReadWritePaths = [ cfg.stateDir ];
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
    systemd.timers.mimir-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };

    # GitHub's published host key.
    programs.ssh.knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
}
