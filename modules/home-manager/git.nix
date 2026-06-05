{ pkgs, ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.email = "github@mrinalpurohit.in";
      user.name = "Mrinal Purohit";
      commit = { gpgSign = true; };
      # add to GitHub as a signing key
      # gh ssh-key add ~/.ssh/id_ed25519.pub - -type signing - -title ${hostname}
      gpg = { format = "ssh"; };
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
        "ssh://git@bitbucket.org/" = { insteadOf = "https://bitbucket.org/"; };
        "ssh://git@github.com/" = { insteadOf = "https://github.com/"; };
      };
    };
  };
}
