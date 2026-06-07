{ lib, ... }: {
  programs.ssh = {
    enable = true;
    # The legacy implicit defaults (ForwardAgent no, Compression no, …) all
    # match OpenSSH's own compiled-in defaults, and the pre-HM config never
    # set them — disable to declare only what we mean (and silence the
    # upcoming deprecation).
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        HostName = "github.com";
        # GitHub's ssh endpoint only accepts the user `git` (the account is
        # identified by the key). The pre-HM config said `User iammrinal0`,
        # which was latent misconfig masked by git@ URLs overriding it —
        # surfaced the first time `ssh -T github.com` was run bare.
        User = "git";
        # Auth consolidated onto the same key git signing uses
        # (modules/home-manager/git.nix) — registered on GitHub both as a
        # signing key and an authentication key.
        IdentityFile = "~/.ssh/id_ed25519";
        # The agent may hold several keys; offer only this one so GitHub
        # doesn't burn auth attempts on the wrong keys.
        IdentitiesOnly = "yes";
      };
      "*" = {
        ControlMaster = "auto";
        ControlPath = "~/.ssh/sockets/%C";
      };
    };
    # Host blocks with IPs and usernames that shouldn't live in a public
    # repo (homelab, cloud instances). Encrypted in sops/secrets.yaml as
    # ssh-config-private, decrypted at activation (secrets list in
    # base.nix). ssh treats a missing Include target as an empty glob, so
    # a host that hasn't decrypted secrets yet still parses the config.
    includes = [ "/run/secrets/ssh-config-private" ];
  };

  # ssh does not create the ControlPath directory itself; materialize it
  # declaratively so multiplexing works on a fresh $HOME.
  home.file.".ssh/sockets/.keep".text = "";

  # vscode-fhs runs in a bubblewrap user namespace where /nix/store files
  # (root-owned) appear as nobody:nogroup, so openssh's "owned by you or
  # root" check rejects the store-symlinked ~/.ssh/config ("Bad owner or
  # permissions"). Verified: a user-owned real file passes, and Include of
  # a store path fails the same check — so the file itself must be a copy.
  # force lets HM re-link over the materialized copy on the next
  # activation, which the hook below then re-materializes.
  home.file.".ssh/config".force = true;
  home.activation.materializeSshConfig =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      sshConfig="$HOME/.ssh/config"
      if [ -L "$sshConfig" ]; then
        run cp --remove-destination "$(readlink -f "$sshConfig")" "$sshConfig"
        run chmod 600 "$sshConfig"
      fi
    '';
}
