{
  enable = true;
  delta.enable = true;
  userName = "Mrinal Purohit";
  userEmail = "github@mrinalpurohit.in";
  extraConfig = {
    fetch = { prune = true; };
    core = { editor = "emacs"; };
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
