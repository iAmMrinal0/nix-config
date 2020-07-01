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
  source <(${kubectl}/bin/kubectl completion zsh)
  '';
  shellAliases = {
    proc = "ps aux | ${ripgrep}/bin/rg $1";
    tmuxnew = "${tmux}/bin/tmux -u attach -t play || ${tmux}/bin/tmux -u new -s play";
    tmuxdir = "new-tmux-from-dir-name";
  };
  oh-my-zsh = {
    enable = true;
    plugins = ["docker" "extract" "git" "kubectl" "sudo"];
    theme = "mod_steeef";
    custom = "\$HOME/.oh-my-zsh/custom";
  };
  plugins = [{
    name = "zsh-autosuggestions";
    src = fetchFromGitHub {
      owner = "zsh-users";
      repo = "zsh-autosuggestions";
      rev = "v0.6.4";
      sha256 = "0h52p2waggzfshvy1wvhj4hf06fmzd44bv6j18k3l9rcx6aixzn6";
    };} {
    name = "nix-zsh-completions";
    src = fetchFromGitHub {
      owner = "spwhitt";
      repo = "nix-zsh-completions";
      rev = "0.4.4";
      sha256 = "1n9whlys95k4wc57cnz3n07p7zpkv796qkmn68a50ygkx6h3afqf";
    };}];
}
