{ pkgs, ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.email = "github@mrinalpurohit.in";
      user.name = "Mrinal Purohit";
      commit = { gpgSign = true; };
      user.signingKey = "E27C4BC509095144";
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
