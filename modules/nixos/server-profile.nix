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
      autosuggestions.enable = true;
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

          # Shared with the desktop shell: open/attach a tmux session named
          # after the current directory (the `tmuxdir` alias calls this).
          function new-tmux-from-dir-name {
            dir_name=$(echo `basename $PWD` | tr '.' '-')
            ${pkgs.tmux}/bin/tmux new-session -As $dir_name
          }
        ''
        # fast-syntax-highlighting must load LAST so it wraps the other zle
        # widgets; mkAfter puts it after oh-my-zsh and autosuggestions. Same
        # plugin as the laptops (they defer + zcompile it for startup speed,
        # which a rarely-launched server shell doesn't need).
        (lib.mkAfter ''
          source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
        '')
      ];
    };

    # Shell-history search + up-arrow, running UNSYNCED here: syncing would land
    # the full cross-machine history (a plaintext sqlite db once synced) on a
    # services box, undoing the point of a lean, blast-radius-limited host. Add
    # `atuin login` + a sops key later if cross-machine history is wanted. The
    # zsh integration and the user daemon default on automatically.
    programs.atuin = {
      enable = true;
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
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = username;
        # HOME is where continuum reads/writes its saved sessions; the socket
        # itself is UID-based so it does not depend on this.
        Environment = [ "HOME=/home/${username}" ];
        # The tmux SERVER lives in this unit's cgroup; the default
        # KillMode=control-group would tear it down (and every session) when the
        # unit is stopped/restarted on rebuild. process leaves the server alone.
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
    ];

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
