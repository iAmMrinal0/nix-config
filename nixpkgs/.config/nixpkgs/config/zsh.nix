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
      src = fetchFromGitHub {
        owner = "spwhitt";
        repo = "nix-zsh-completions";
        rev = "0.4.4";
        sha256 = "1n9whlys95k4wc57cnz3n07p7zpkv796qkmn68a50ygkx6h3afqf";
      };
    }
    {
      name = "zsh-syntax-highlighting";
      src = fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-syntax-highlighting";
        rev = "0.7.1";
        sha256 = "03r6hpb5fy4yaakqm3lbf4xcvd408r44jgpv4lnzl9asp4sb9qc0";
      };
    }
  ];
}
