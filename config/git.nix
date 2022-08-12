{
  enable = true;
  userName = "Mrinal Purohit";
  userEmail = "github@mrinalpurohit.in";
  includes = [{
    contents = {
      user.name = "Mrinal Purohit";
      user.email = "mrinal.purohit@juspay.in";
      pull.rebase = true;
      rebase.autostash = true;
    };
    condition = "gitdir:~/play/";
  }];
  extraConfig = {
    fetch = { prune = true; };
    core = { editor = "vim"; };
    rerere = { enabled = true; };
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
