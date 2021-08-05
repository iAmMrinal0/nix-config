{ lib, pkgs, ... }:

let zshCustom = pkgs.callPackage ./modSteeefZsh.nix { };
in {
  enable = true;
  enableCompletion = true;
  defaultKeymap = "emacs";
  history.expireDuplicatesFirst = true;
  history.extended = true;

  initExtra = ''
    setopt HIST_IGNORE_ALL_DUPS
    function new-tmux-from-dir-name {
      dir_name=$(echo `basename $PWD` | tr '.' '-')
      ${pkgs.tmux}/bin/tmux new-session -As $dir_name
    }
    source <(${pkgs.kubectl}/bin/kubectl completion zsh)
  '';
  shellAliases = {
    proc = "ps aux | ${pkgs.ripgrep}/bin/rg $1";
    tmuxnew =
      "${pkgs.tmux}/bin/tmux -u attach -t play || ${pkgs.tmux}/bin/tmux -u new -s play";
    tmuxdir = "new-tmux-from-dir-name";
    br = "${pkgs.broot}/bin/broot";
  };
  oh-my-zsh = {
    enable = true;
    plugins = [ "command-not-found" "docker" "extract" "git" "kubectl" "sudo" ];
    theme = "mod_steeef";
    custom = "${zshCustom}";
  };
  plugins = [
    {
      name = "zsh-autosuggestions";
      src = pkgs.fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-autosuggestions";
        rev = "v0.7.0";
        sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
      };
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
      src = pkgs.fetchFromGitHub {
        owner = "MichaelAquilina";
        repo = "zsh-you-should-use";
        rev = "ccc7e7f75bd7169758a1c931ea574b96b71aa9a0";
        sha256 = "sha256-hTJjeJT9szHl9HXDHaSEmkv3wOARORs7sQA8/MjkfIo=";
      };
    }
    {
      name = "zsh-history-substring-search";
      src = pkgs.fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-history-substring-search";
        rev = "4abed97b6e67eb5590b39bcd59080aa23192f25d";
        sha256 = "sha256-8kiPBtgsjRDqLWt0xGJ6vBBLqCWEIyFpYfd+s1prHWk=";
      };
    }
    {
      name = "zsh-nix-shell";
      file = "nix-shell.plugin.zsh";
      src = pkgs.fetchFromGitHub {
        owner = "chisui";
        repo = "zsh-nix-shell";
        rev = "v0.4.0";
        sha256 = "037wz9fqmx0ngcwl9az55fgkipb745rymznxnssr3rx9irb6apzg";
      };
    }
  ];
}
