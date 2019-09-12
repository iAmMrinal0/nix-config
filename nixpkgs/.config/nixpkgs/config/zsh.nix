{pkgs, ...}:

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
  eval "$(${direnv}/bin/direnv hook zsh)"
  '';
  shellAliases = {
    proc = "ps aux | ${ripgrep}/bin/rg $1";
    tmuxnew = "${tmux}/bin/tmux -u attach -t play || ${tmux}/bin/tmux -u new -s play";
    tmuxdir = "new-tmux-from-dir-name";
  };
  oh-my-zsh = {
    enable = true;
    plugins = ["docker" "extract" "git" "sudo"];
    theme = "mod_steeef";
    custom = "\$HOME/.oh-my-zsh/custom";
  };
  plugins = [
    {
      name = "zsh-autosuggestions";
      src = fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-autosuggestions";
        rev = "v0.5.2";
        sha256 = "1xhrdv6cgmq9qslb476rcs8ifw8i2vf43yvmmscjcmpz0jac4sbx";
      };
    }
    {
      name = "nix-zsh-completions";
      src = fetchFromGitHub {
        owner = "spwhitt";
        repo = "nix-zsh-completions";
        rev = "0.4.3";
        sha256 = "0fq1zlnsj1bb7byli7mwlz7nm2yszwmyx43ccczcv51mjjfivyp3";
      };
    }
  ];
}
