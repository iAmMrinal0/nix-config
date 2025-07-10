{ pkgs, inputs, ... }:

let
  shellAliases = {
    tmuxnew = "tmux -u attach -t play || tmux -u new -s play";
    tmuxdir = "new-tmux-from-dir-name";
  };
in {
  home.packages = with pkgs; [ tmux ripgrep ];
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    defaultKeymap = "emacs";
    history.expireDuplicatesFirst = true;
    history.extended = true;

    shellAliases = shellAliases;
    initContent = ''
      setopt HIST_FIND_NO_DUPS
      setopt HIST_IGNORE_ALL_DUPS
      function new-tmux-from-dir-name {
        dir_name=$(echo `basename $PWD` | tr '.' '-')
        ${pkgs.tmux}/bin/tmux new-session -As $dir_name
      }
      ZSH_AUTOSUGGEST_STRATEGY=( abbreviations $ZSH_AUTOSUGGEST_STRATEGY )
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "command-not-found" "docker" "extract" "git" "sudo" ];
      theme = "mod_steeef";
      custom = "${pkgs.callPackage ./modSteeefZsh.nix { }}";
    };
    zsh-abbr = {
      enable = true;
      abbreviations = { proc = "ps aux | rg"; } // shellAliases;
    };
    plugins = [
      {
        name = "zsh-autosuggestions";
        src = "${inputs.zsh-autosuggestions}";
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
        src = inputs.zsh-you-should-use;
      }
      {
        name = "zsh-autosuggestions-abbreviations-strategy";
        src = inputs.zsh-autosuggestions-abbreviations-strategy;
      }
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = inputs.zsh-nix-shell;
      }
    ];
  };
}
