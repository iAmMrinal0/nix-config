{pkgs, ...}:

with pkgs;

{
  enable = true;
  enableCompletion = true;
  defaultKeymap = "emacs";
  history.expireDuplicatesFirst = true;
  history.extended = true;
  shellAliases = {
    proc = "ps aux | ${ripgrep}/bin/rg $1";
    tmuxnew = "${tmux}/bin/tmux -u attach -t play || ${tmux}/bin/tmux -u new -s play";
  };
  oh-my-zsh = {
    enable = true;
    plugins = ["git" "sudo" "extract"];
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
