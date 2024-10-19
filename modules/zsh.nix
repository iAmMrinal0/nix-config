{ pkgs, zsh-autosuggestions, zsh-you-should-use, zsh-nix-shell, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    defaultKeymap = "emacs";
    history.expireDuplicatesFirst = true;
    history.extended = true;

    initExtra = ''
      setopt HIST_FIND_NO_DUPS
      setopt HIST_IGNORE_ALL_DUPS
      function new-tmux-from-dir-name {
        dir_name=$(echo `basename $PWD` | tr '.' '-')
        ${pkgs.tmux}/bin/tmux new-session -As $dir_name
      }
    '';
    shellAliases = {
      proc = "ps aux | ${pkgs.ripgrep}/bin/rg $1";
      tmuxnew =
        "${pkgs.tmux}/bin/tmux -u attach -t play || ${pkgs.tmux}/bin/tmux -u new -s play";
      tmuxdir = "new-tmux-from-dir-name";
      # br = "${pkgs.broot}/bin/broot";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [ "command-not-found" "docker" "extract" "git" "sudo" ];
      theme = "mod_steeef";
      custom = "${pkgs.callPackage ../config/modSteeefZsh.nix { }}";
    };
    plugins = [
      {
        name = "zsh-autosuggestions";
        src = "${zsh-autosuggestions}";
      }
      {
        name = "nix-zsh-completions";
        src = "${pkgs.nix-zsh-completions}/share/zsh/site-functions";
      }
      {
        name = "fast-syntax-highlighting";
        src = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
      }
      {
        name = "you-should-use";
        src = zsh-you-should-use;
      }
      # {
      #   name = "zsh-history-substring-search";
      #   src = zsh-history-substring-search;
      # }
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = zsh-nix-shell;
      }
    ];
  };
}
