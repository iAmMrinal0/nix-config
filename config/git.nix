{
  enable = true;
  userName = "Mrinal Purohit";
  userEmail = "github@mrinalpurohit.in";
  extraConfig = {
    user = {
      signingKey = "E27C4BC509095144";
    };
    commit = {
      gpgSign = true;
    };
    fetch = { prune = true; };
    core = { editor = "vim"; };
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
    mergetool = {
      ediff = {
        cmd =
          "emacsclient -a '' --eval \"(ediff-merge-files-with-ancestor \\\"$LOCAL\\\" \\\"$REMOTE\\\" \\\"$BASE\\\" nil \\\"$MERGED\\\")\"";
      };
    };
  };
}
