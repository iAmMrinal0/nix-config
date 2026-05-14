{ pkgs, inputs, ... }:

let
  shellAliases = {
    cal = "cal -w"; # show week numbers (Monday-start comes from en_GB locale)
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
    sessionVariables = {
      # Skip oh-my-zsh's compaudit security check on every startup
      # (saves ~100ms; nix store paths are already trusted).
      ZSH_DISABLE_COMPFIX = "true";
    };
    initContent = ''
      # Reload zsh completions from direnv-exported KRONOR_ZSH_COMPLETIONS.
      # Uses compinit -C: the dump was already built by oh-my-zsh's compinit at
      # startup, and adding an fpath entry doesn't require re-auditing.
      typeset -g _kronor_completions_loaded=""
      _kronor_completions_hook() {
        local dir="$KRONOR_ZSH_COMPLETIONS"
        [[ -n "$dir" && -d "$dir" && "$_kronor_completions_loaded" != "$dir" ]] || return 0
        fpath=("$dir" $fpath)
        autoload -Uz compinit
        compinit -C
        _kronor_completions_loaded="$dir"
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _kronor_completions_hook
      setopt HIST_FIND_NO_DUPS
      setopt HIST_IGNORE_ALL_DUPS
      function new-tmux-from-dir-name {
        dir_name=$(echo `basename $PWD` | tr '.' '-')
        ${pkgs.tmux}/bin/tmux new-session -As $dir_name
      }
      ZSH_AUTOSUGGEST_STRATEGY=( abbreviations $ZSH_AUTOSUGGEST_STRATEGY )

      source "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "extract" "git" "sudo" ];
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
