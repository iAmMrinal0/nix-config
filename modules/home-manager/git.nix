{ pkgs, ... }:
let
  # Shared with hosts that configure git without home-manager (yggdrasil).
  identity = import ../git-identity.nix;
  # Lets `git log --show-signature` verify our own ssh-signed commits
  # offline: maps the signing identity (committer email) to the
  # per-machine public keys (the same id_ed25519 keys registered on
  # GitHub — public material, fine for a public repo; the email is
  # already this repo's commit identity). Both keys listed so either
  # machine verifies the other's commits. Work-email commits live in
  # work repos and aren't verified by this file — deliberately not
  # listing an org email in a public repo.
  allowedSigners = pkgs.writeText "git-allowed-signers" ''
    ${identity.email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2VaKwjYmaBmrbVp14QFZBguI9ah8hC+sw91OYH6bg7 betazed
    ${identity.email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4eqGHhyS/WC3vgY19Ij5ycL0gJmVt7EcWRgmKBUdbb mordor
  '';
in {
  programs.git = {
    enable = true;
    settings = {
      user.email = identity.email;
      user.name = identity.name;
      commit = { gpgSign = true; };
      # add to GitHub as a signing key
      # gh ssh-key add ~/.ssh/id_ed25519.pub - -type signing - -title ${hostname}
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = toString allowedSigners;
      };
      user.signingKey = "~/.ssh/id_ed25519.pub";
      fetch = { prune = true; };
      rerere = { enabled = true; };
      pull = { rebase = true; };
      push = { autoSetupRemote = true; };
      rebase = { autostash = true; };
      merge = {
        conflictstyle = "diff3";
        tool = "ediff";
        renormalize = true;
      };
      status = { showUntrackedFiles = "all"; };
      url = {
        "ssh://git@github.com/" = { insteadOf = "https://github.com/"; };
      };
    };
  };
}
