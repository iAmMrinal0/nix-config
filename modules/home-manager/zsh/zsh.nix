{ config, pkgs, lib, inputs, ... }:

let
  shellAliases = {
    cal = "cal -w"; # show week numbers (Monday-start comes from en_GB locale)
    tmuxnew = "tmux -u attach -t play || tmux -u new -s play";
    tmuxdir = "new-tmux-from-dir-name";
    proc = "ps aux | rg";
    # DisplayLink renames DVI-I-* outputs between docks/reboots and saved
    # CRTC/gamma values go stale: match monitors by EDID and let X pick CRTCs.
    autorandr = "autorandr --match-edid --skip-options crtc,gamma";
  };

  # Copy a plugin directory into a derivation, then zcompile the named
  # entrypoint inside it so `source` uses the precompiled wordcode. The whole
  # directory is copied so plugins that read sibling files (e.g.
  # fast-syntax-highlighting needs fast-highlight, .fast-* helpers) still work.
  zcompileDir = name: srcDir:
    pkgs.runCommandLocal name { } ''
      mkdir -p $out
      cp -r ${srcDir}/. $out/
      chmod -R u+w $out
      ${pkgs.zsh}/bin/zsh -c "zcompile $out/${name}"
    '';

  # Bake `atuin init zsh` into a static file at build time so we don't pay
  # the ~8ms fork+exec at every shell start. Source order matters: this
  # must defer-load before zsh-autosuggestions (atuin prepends itself to
  # ZSH_AUTOSUGGEST_STRATEGY, which autosuggestions reads at init time).
  atuinInit = pkgs.runCommandLocal "atuin-init.zsh" { } ''
    export HOME=$(mktemp -d)
    mkdir -p $out
    ${pkgs.atuin}/bin/atuin init zsh > $out/atuin-init.zsh
    ${pkgs.zsh}/bin/zsh -c "zcompile $out/atuin-init.zsh"
  '';
in {
  home.packages = with pkgs; [ tmux ripgrep ];

  # Pre-build ~/.zcompdump during activation so the first interactive shell
  # after a rebuild doesn't pay compinit's ~1s dump-rebuild cost (Nix bumps
  # fpath mtimes on every switch, marking the dump stale).
  # stderr is intentionally not suppressed: if zsh prints startup errors,
  # they surface in the `nixos-rebuild switch` output instead of greeting
  # the next terminal you open.
  home.activation.warmZcompdump = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.zsh}/bin/zsh -i -c exit > /dev/null
  '';

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    defaultKeymap = "emacs";
    # 26.05 changes the dotDir default from $HOME to $XDG_CONFIG_HOME/zsh;
    # adopt the new XDG location. HM regenerates .zshrc/.zshenv there and
    # drops a $HOME/.zshenv stub that points ZDOTDIR at it, so this is
    # transparent — EXCEPT history.path defaults to "${dotDir}/.zsh_history",
    # which would orphan the existing ~/.zsh_history. Pin it to $HOME so
    # accumulated history survives the move.
    dotDir = "${config.xdg.configHome}/zsh";
    history.path = "${config.home.homeDirectory}/.zsh_history";
    history.expireDuplicatesFirst = true;
    history.extended = true;

    shellAliases = shellAliases;
    sessionVariables = {
      # Skip oh-my-zsh's compaudit security check on every startup
      # (saves ~100ms; nix store paths are already trusted).
      ZSH_DISABLE_COMPFIX = "true";
    };
    # Inject the cachix auth token (sops secret) into cachix invocations
    # ONLY, via a wrapper function — deliberately not a global export:
    # an env var in .zshenv would put a write-token to the public cache
    # into the environment of every process (leak-prone via error
    # reporters, build logs, debug dumps). The token is read from the
    # secret file at invocation time, never at eval time, so it can't end
    # up in the nix store. envExtra (.zshenv) so it works in any zsh, not
    # just interactive ones. $CACHIX_AUTH_TOKEN already set (e.g. CI or a
    # manual export) wins; missing secret file degrades to plain cachix.
    envExtra = ''
      cachix() {
        if [[ -z "$CACHIX_AUTH_TOKEN" && -r /run/secrets/cachix-auth-token ]]; then
          CACHIX_AUTH_TOKEN="$(</run/secrets/cachix-auth-token)" command cachix "$@"
        else
          command cachix "$@"
        fi
      }
    '';
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

      # Remote hosts lack the xterm-kitty terminfo entry, so ncurses apps
      # error out over ssh. `kitten ssh` installs it into the remote login
      # user's ~/.terminfo on connect (keeps TERM honest, unlike faking it).
      # Interactive-only, so git/rsync and scripts still use the real binary.
      if [[ "$TERM" == xterm-kitty ]]; then
        function ssh {
          ${config.programs.kitty.package}/bin/kitten ssh "$@"
        }
      fi

      # ~/.terminfo doesn't survive sudo (it resets $HOME to /root), so run
      # this once per host to install xterm-kitty system-wide for sudo'd TUIs.
      function ssh-setup-terminfo {
        local host="''${1:?usage: ssh-setup-terminfo <host>}"
        infocmp -x xterm-kitty | command ssh "$host" 'cat > /tmp/.xterm-kitty.ti' \
          && command ssh -t "$host" \
            'sudo tic -x -o /usr/share/terminfo /tmp/.xterm-kitty.ti && rm -f /tmp/.xterm-kitty.ti' \
          && echo "xterm-kitty installed system-wide on $host"
      }

      # Defer heavy plugins until after the first prompt renders. They
      # initialize a few ms later via a precmd hook — invisible unless you
      # type the instant the prompt appears (autosuggestions/syntax colors
      # would be a beat late on that first keystroke).
      # Order matters: atuin must load before autosuggestions so it can
      # register itself as a suggestion strategy.
      source ${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh
      zsh-defer source ${atuinInit}/atuin-init.zsh
      zsh-defer source ${
        zcompileDir "zsh-autosuggestions.zsh" inputs.zsh-autosuggestions
      }/zsh-autosuggestions.zsh
      zsh-defer source ${
        zcompileDir "nix-shell.plugin.zsh" inputs.zsh-nix-shell
      }/nix-shell.plugin.zsh
      zsh-defer source ${
        zcompileDir "fast-syntax-highlighting.plugin.zsh"
        "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting"
      }/fast-syntax-highlighting.plugin.zsh
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "extract" "git" "sudo" ];
      theme = "mod_steeef";
      custom = "${pkgs.callPackage ./modSteeefZsh.nix { }}";
    };
    # Only sync plugins here — heavy ones are deferred in initContent above.
    plugins = [{
      name = "nix-zsh-completions";
      src = "${pkgs.nix-zsh-completions}/share/zsh/site-functions";
    }];
  };
}
