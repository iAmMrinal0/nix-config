{ config, pkgs, lib, username, ... }:

# Reusable "this machine is a server" profile: the shell niceties and CLI tools
# that make a headless box pleasant to operate over SSH, without the desktop
# base.nix (Wayland/X11/audio/home-manager). Turn it on with
# `modules.server.enable = true;` on any headless host.
#
# Deliberately system-level, NOT home-manager: a server carries a single admin
# user and the whole config is ~20 lines of NixOS options, so a home-manager
# profile would add a framework without removing duplication. Everything that
# must stay identical to the desktops is shared as plain data (same
# single-source-of-truth pattern as modules/git-identity.nix):
#   - shell aliases  -> modules/shell-aliases.nix
#   - tmux config    -> modules/tmux-common.nix
#   - atuin settings -> modules/atuin-settings.nix

let
  cfg = config.modules.server;
  adminUser = config.users.users.${username};

  # A forwarded SSH agent is how a headless box gets a GitHub key without ever
  # holding one at rest — but sshd plants the forwarded socket at a fresh
  # /tmp/ssh-XXXXXX/agent.NNN per connection and unlinks it on disconnect. So
  # the raw path is worthless to anything longer-lived than one session: a tmux
  # pane that captured it is stranded on the next reattach, and the boot server
  # below never had one at all. Republish it under ONE stable path that every
  # login repoints, and hand that path to tmux + the shell instead.
  agentSock = "${adminUser.home}/.ssh/agent.sock";

  # Repoint the stable path at THIS connection's socket. Silent and non-fatal
  # deliberately: it also runs from /etc/ssh/sshrc, whose stdout travels down
  # the client's channel, where a stray byte corrupts scp/sftp.
  linkAgentSock = ''
    if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "${agentSock}" ]; then
      ln -sfn "$SSH_AUTH_SOCK" "${agentSock}" 2>/dev/null || :
    fi
  '';
in {
  options.modules.server = {
    enable = lib.mkEnableOption
      "the headless server profile (zsh + atuin + tmux + CLI tools)";

    tmux = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Start a detached tmux session at boot (as a system service running
          as the admin user) so `tmux attach` works immediately over SSH,
          without first logging in interactively to spawn the server.
        '';
      };
      sessionName = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Name of the boot session (what `tmux attach` lands on).";
      };
      workingDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/iammrinal0/apps";
        description = ''
          Working directory the boot session opens in. Null means the user's
          home. Falls back to home at runtime if the path does not exist yet.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # zsh as the login shell for every normal user on the box.
    users.defaultUserShell = pkgs.zsh;

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      # Sourced by hand at the end of interactiveShellInit instead of here: this
      # option emits it too early, and atuin has to load first (see that block).
      autosuggestions.enable = false;
      # This option would ship zsh-users' "zsh-syntax-highlighting"; the laptops
      # use fast-syntax-highlighting (F-Sy-H), which colours differently. Keep
      # it off and source F-Sy-H (the same package) in interactiveShellInit so
      # the highlighting matches the desktops.
      syntaxHighlighting.enable = false;
      shellAliases = import ../shell-aliases.nix;
      # oh-my-zsh supplies the interactive niceties (AUTO_CD, the completion
      # menu + colours, the git/sudo/extract plugins) and the prompt — the same
      # framework the laptops run, so behaviour matches instead of being
      # hand-maintained as raw setopts. The NixOS oh-my-zsh module already sets
      # promptInit = "" itself, so the stock prompt won't clobber the theme.
      # Startup cost (~150-300ms/shell) is irrelevant on an occasional-SSH box,
      # so none of the desktop's zcompile/defer machinery is needed here.
      ohMyZsh = {
        enable = true;
        # Same prompt as the desktops, reusing the ONE theme file
        # (modules/home-manager/zsh/modSteeefZsh.nix) as the single source.
        theme = "mod_steeef";
        custom = "${pkgs.callPackage ../home-manager/zsh/modSteeefZsh.nix { }}";
        plugins = [ "extract" "git" "sudo" ];
      };
      interactiveShellInit = lib.mkMerge [
        ''
          # Not in oh-my-zsh's history defaults; match the desktop shell.
          setopt HIST_FIND_NO_DUPS
          setopt HIST_IGNORE_ALL_DUPS

          ${linkAgentSock}
          # -S follows the symlink, so a dangling one (nothing forwarded, e.g.
          # a console login) leaves SSH_AUTH_SOCK untouched rather than aiming
          # ssh at a missing socket. This also overrides whatever tmux handed
          # the pane — update-environment (modules/tmux-common.nix) copies the
          # attaching client's raw /tmp path — so every pane, however old,
          # agrees on the one path that survives a reattach. `if` rather than
          # `&&` so a false test does not leave $? set at the first prompt.
          if [ -S "${agentSock}" ]; then
            export SSH_AUTH_SOCK="${agentSock}"
          fi

          # Shared with the desktop shell: open/attach a tmux session named
          # after the current directory (the `tmuxdir` alias calls this).
          function new-tmux-from-dir-name {
            dir_name=$(echo `basename $PWD` | tr '.' '-')
            ${pkgs.tmux}/bin/tmux new-session -As $dir_name
          }
        ''
        # The heavy plugins, loaded in the SAME ORDER as the laptops
        # (modules/home-manager/zsh/zsh.nix): atuin -> autosuggestions ->
        # fast-syntax-highlighting. Sourced here rather than via the individual
        # NixOS options because those options append to interactiveShellInit
        # *unordered*, so their relative order falls out of nixpkgs module-list
        # positions — atuin (171) lands before oh-my-zsh (383) before
        # autosuggestions (387) — which is the wrong order twice over:
        #   - oh-my-zsh's lib/key-bindings.zsh rebinds ^r and the up arrow, so
        #     an atuin that loaded earlier silently loses both (^r fell back to
        #     zsh's bck-i-search here, while the laptops were fine). mkAfter
        #     puts this whole chain after oh-my-zsh, so atuin's own bindings
        #     win — no re-binding by hand.
        #   - atuin must precede autosuggestions: it prepends itself to
        #     ZSH_AUTOSUGGEST_STRATEGY, which autosuggestions reads at init
        #     time (the same constraint the laptops' comment calls out).
        # fast-syntax-highlighting stays LAST so it wraps every widget the
        # others define. No zsh-defer/zcompile: the laptops use those purely
        # for startup speed, which doesn't matter on an occasional-SSH box.
        (lib.mkAfter ''
          eval "$(${config.programs.atuin.package}/bin/atuin init zsh)"
          source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
          source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
        '')
      ];
    };

    # Shell-history search + up-arrow, running UNSYNCED here: syncing would land
    # the full cross-machine history (a plaintext sqlite db once synced) on a
    # services box, undoing the point of a lean, blast-radius-limited host. Add
    # `atuin login` + a sops key later if cross-machine history is wanted. The
    # user daemon defaults on automatically; the zsh integration does too, but
    # it is turned off below because it injects `atuin init zsh` too early to
    # survive oh-my-zsh's keybindings — interactiveShellInit sources it in the
    # right place instead. Package + settings + daemon all still come from here.
    programs.atuin = {
      enable = true;
      enableZshIntegration = false;
      settings = import ../atuin-settings.nix;
    };

    programs.tmux = {
      enable = true;
      baseIndex = 1;
      clock24 = true;
      historyLimit = 100000;
      terminal = "tmux-256color";
      # Keep the socket at /tmp/tmux-<uid> (the default when unset), NOT under
      # /run/user/<uid>. secureSocket = true (the module default) exports
      # TMUX_TMPDIR=/run/user/<uid> via /etc/set-environment, which reaches
      # interactive login shells but NOT the tmux-boot system service below — so
      # the boot server (socket in /tmp) and an SSH shell's `tmux attach` (socket
      # in /run/user) would never meet. /run/user is also cleared by logind on
      # last logout (no lingering here), so a "persistent" session would not
      # survive a disconnect there anyway. /tmp is UID-keyed and only wiped at
      # boot (boot.tmp.cleanOnBoot), before this service starts.
      secureSocket = false;
      plugins = with pkgs.tmuxPlugins; [ resurrect continuum copycat ];
      # continuum reads @continuum-restore when it initializes, so the option
      # must be set before the plugin is sourced.
      extraConfigBeforePlugins = "set -g @continuum-restore 'on'";
      extraConfig = (import ../tmux-common.nix { inherit pkgs; }) + ''

        # Reload the system tmux config (NixOS writes it to /etc/tmux.conf).
        bind r source-file /etc/tmux.conf \; display "Configuration reloaded."

        # No local clipboard on a headless box: accept OSC52 from apps and let
        # tmux forward copies to the SSH client's terminal clipboard.
        set -g set-clipboard on

        # The tmux-boot SYSTEM service starts the server without SHELL=zsh in
        # its environment, so panes would default to bash. Pin the login shell
        # so every pane (boot-started or interactive) is zsh.
        set -g default-shell ${pkgs.zsh}/bin/zsh

        # Hand every pane the stable agent path. The boot session's own pane
        # gets it too: the server sources this file when it starts, before it
        # creates the session, so the pane you land on after `tmux attach` is
        # born with it — which is the whole point, since that pane predates
        # every SSH connection and update-environment only reaches panes
        # created after an attach. Pinning the forwarded socket's real /tmp
        # path here instead would be useless: it changes each connection.
        set-environment -g SSH_AUTH_SOCK ${agentSock}
      '';
    };

    # Boot a detached tmux session as the admin user so `tmux attach` just works
    # over SSH. A SYSTEM service (not a user service + linger) because it must
    # come up at boot without an interactive login; tmux keys its socket on the
    # UID (/tmp/tmux-<uid>), which is exactly where an SSH login shell's tmux
    # looks too, so the running session is found with no TMUX_TMPDIR coupling.
    systemd.services.tmux-boot = lib.mkIf cfg.tmux.autoStart {
      description =
        "Boot a detached tmux session for ${username} so `tmux attach` just works";
      wantedBy = [ "multi-user.target" ];
      # tmux resolves a `display-popup` argv with execvp against the SERVER's
      # PATH, and NixOS's default service path (coreutils, findutils, gnugrep,
      # gnused, systemd) ships no shell — so atuin's ^r popup
      # (`... -E -E -- sh -c '... atuin search -i ...'`) could not find `sh`
      # and left an empty popup on screen: the failed exec prints nothing, and
      # two -E close a popup only on a ZERO exit. Via `path`, which merges with
      # that default, and not a PATH= line in Environment, which is emitted
      # later and would replace it.
      path = [ "/run/current-system/sw" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = username;
        # HOME is where continuum reads/writes its saved sessions; the socket
        # itself is UID-based so it does not depend on this.
        # ATUIN_CONFIG_DIR: the atuin module ships it in environment.variables,
        # i.e. /etc/set-environment, which neither a system service nor the
        # popup's non-interactive `sh -c` reads — so without it the atuin in
        # the popup runs on stock defaults, not modules/atuin-settings.nix.
        Environment = [
          "HOME=/home/${username}"
          "ATUIN_CONFIG_DIR=${config.environment.variables.ATUIN_CONFIG_DIR}"
        ];
        # The tmux SERVER lives in this unit's cgroup; the default
        # KillMode=control-group would tear it down (and every session) when the
        # unit is stopped/restarted on rebuild. process leaves the server alone.
        # The flip side: a surviving server keeps the environment it was born
        # with, so the two settings above only reach it after a
        # `tmux kill-server` (continuum restores) or a `tmux setenv -g`.
        KillMode = "process";
        ExecStart = pkgs.writeShellScript "tmux-boot" ''
          dir=${
            if cfg.tmux.workingDir == null then
              "\"$HOME\""
            else
              lib.escapeShellArg cfg.tmux.workingDir
          }
          [ -d "$dir" ] || dir="$HOME"
          # new-session boots the server (sourcing /etc/tmux.conf + running
          # continuum's auto-restore); a concurrent restore may recreate the
          # session first, so has-session treats "duplicate session" as success.
          # Not `-A`: that switches to attach-session, which needs a TTY a
          # service does not have ("open terminal failed: not a terminal").
          ${pkgs.tmux}/bin/tmux new-session -d -s ${
            lib.escapeShellArg cfg.tmux.sessionName
          } -c "$dir" 2>/dev/null \
            || ${pkgs.tmux}/bin/tmux has-session -t ${
              lib.escapeShellArg cfg.tmux.sessionName
            }
        '';
      };
    };

    # NixOS's global zsh files (/etc/zshrc etc.) don't create a per-user
    # startup file, and zsh runs its interactive `zsh-newuser-install` wizard
    # for any account that has none — blocking every fresh SSH login until you
    # dismiss it. Drop an empty ~/.zshrc so the wizard never fires; all real
    # config still comes from the global rcs, which load regardless. `f` only
    # creates the file if absent, so a hand-written ~/.zshrc is never clobbered.
    systemd.tmpfiles.rules = [
      "f ${adminUser.home}/.zshrc 0644 ${username} ${adminUser.group} - -"
      # openssh.authorizedKeys.keys renders to /etc/ssh/authorized_keys.d, so
      # nothing else creates ~/.ssh on a key-only host — and the agent symlink
      # above needs it to exist. `d` leaves an existing directory alone.
      "d ${adminUser.home}/.ssh 0700 ${username} ${adminUser.group} - -"
    ];

    # sshd runs this for EVERY openssh session, including `ssh <host> <cmd>`
    # and `ssh -t <host> tmux attach`, neither of which sources an interactive
    # zshrc — so the stable socket is current even when no login shell ran.
    # Caveat: Tailscale SSH serves tailnet port 22 from tailscaled itself and
    # does not run sshrc, so that path relies on the zshrc copy above (fine for
    # an interactive login, which is how the tailnet route is used).
    environment.etc."ssh/sshrc".text = linkAgentSock;

    environment.systemPackages = with pkgs; [
      ripgrep
      fzf
      btop
      lazydocker
      # Install the xterm-kitty terminfo entry so ncurses/TUI apps work when we
      # `kitten ssh` in from a kitty terminal (the desktop side installs it into
      # the remote ~/.terminfo otherwise; declaring it here is cleaner).
      kitty.terminfo
    ];
  };
}
