{ lib, pkgs, systems, zshCustom, ... }:

let
  darwinInit = lib.optionalString (builtins.currentSystem == systems.darwin) ''
    export PATH=$PATH:/usr/local/bin:/usr/sbin
    . $HOME/.nix-profile/etc/profile.d/nix.sh
  '';
in {
  enable = true;
  enableCompletion = true;
  defaultKeymap = "emacs";
  history.expireDuplicatesFirst = true;
  history.extended = true;

  initExtra = ''
    ${darwinInit}
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
        rev = "v0.6.4";
        sha256 = "0h52p2waggzfshvy1wvhj4hf06fmzd44bv6j18k3l9rcx6aixzn6";
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
        rev = "1.7.3";
        sha256 = "1dz48rd66priqhxx7byndqhbmlwxi1nfw8ik25k0z5k7k754brgy";
      };
    }
    {
      name = "zsh-history-substring-search";
      src = pkgs.fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-history-substring-search";
        rev = "0f80b8eb3368b46e5e573c1d91ae69eb095db3fb";
        sha256 = "0y8va5kc2ram38hbk2cibkk64ffrabfv1sh4xm7pjspsba9n5p1y";
      };
    }
    {
      name = "zsh-nix-shell";
      file = "nix-shell.plugin.zsh";
      src = pkgs.fetchFromGitHub {
        owner = "chisui";
        repo = "zsh-nix-shell";
        rev = "v0.2.0";
        sha256 = "1gfyrgn23zpwv1vj37gf28hf5z0ka0w5qm6286a7qixwv7ijnrx9";
      };
    }
  ];
}
