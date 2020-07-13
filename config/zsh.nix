{ pkgs, zshCustom, ... }:

with pkgs;

{
  enable = true;
  enableCompletion = true;
  defaultKeymap = "emacs";
  history.expireDuplicatesFirst = true;
  history.extended = true;
  initExtra = ''
  function new-tmux-from-dir-name {
    dir_name=$(echo `basename $PWD` | tr '.' '-')
    ${tmux}/bin/tmux new-session -As $dir_name
  }
  source <(${kubectl}/bin/kubectl completion zsh)
  '';
  shellAliases = {
    proc = "ps aux | ${ripgrep}/bin/rg $1";
    tmuxnew = "${tmux}/bin/tmux -u attach -t play || ${tmux}/bin/tmux -u new -s play";
    tmuxdir = "new-tmux-from-dir-name";
  };
  oh-my-zsh = {
    enable = true;
    plugins = ["command-not-found" "docker" "extract" "git" "kubectl" "sudo"];
    theme = "mod_steeef";
    custom = "${zshCustom}";
  };
  plugins = [
    {
      name = "zsh-autosuggestions";
      src = fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-autosuggestions";
        rev = "v0.6.4";
        sha256 = "0h52p2waggzfshvy1wvhj4hf06fmzd44bv6j18k3l9rcx6aixzn6";
      };
    }
    {
      name = "nix-zsh-completions";
      src = "${nix-zsh-completions}/share/zsh/site-functions";
    }
    {
      name = "fast-syntax-highlighting";
      src = "${zsh-fast-syntax-highlighting}/share/zsh/site-functions";
    }
    {
      name = "you-should-use";
      src = fetchFromGitHub {
        owner = "MichaelAquilina";
        repo = "zsh-you-should-use";
        rev = "1.7.0";
        sha256 = "1gcxm08ragwrh242ahlq3bpfg5yma2cshwdlj8nrwnd4qwrsflgq";
      };
    }
    {
      name = "zsh-history-substring-search";
      src = fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-history-substring-search";
        rev = "0f80b8eb3368b46e5e573c1d91ae69eb095db3fb";
        sha256 = "0y8va5kc2ram38hbk2cibkk64ffrabfv1sh4xm7pjspsba9n5p1y";
      };
    }
  ];
}
