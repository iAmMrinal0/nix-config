{ pkgs, config, ... }:

let
  # Runtime-dispatching clipboard wrappers: pick wl-clipboard under Wayland,
  # xclip under X11. Lets the same tmux config work on betazed (sway) and
  # mordor (i3) without conditional nix.
  #
  # Copy fills PRIMARY as well as CLIPBOARD, and paste reads PRIMARY — that
  # mirrors the pre-wrapper xclip bindings, where copy-mode selections were
  # middle-click pasteable and C-y inserted the current mouse selection.
  # WAYLAND_DISPLAY discovery: tmux pipes run with the SERVER's environment,
  # and the server is born from tmux-server.service (systemd.nix pre-warm)
  # before sway has imported WAYLAND_DISPLAY into the user manager — so the
  # env check alone always fell through to xclip under sway. If the var is
  # unset, look for a live wayland socket in XDG_RUNTIME_DIR instead of
  # trusting the inherited env (the socket name varies, so no hardcoding).
  findWayland = ''
    if [ -z "$WAYLAND_DISPLAY" ]; then
      for s in "''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"/wayland-*; do
        case "$s" in *.lock) continue ;; esac
        [ -S "$s" ] && export WAYLAND_DISPLAY="''${s##*/}" && break
      done
    fi
  '';
  clipCopy = pkgs.writeShellScript "tmux-clip-copy" ''
    ${findWayland}
    if [ -n "$WAYLAND_DISPLAY" ]; then
      ${pkgs.coreutils}/bin/tee >(${pkgs.wl-clipboard}/bin/wl-copy --primary) \
        | ${pkgs.wl-clipboard}/bin/wl-copy
    else
      # No -f on the primary xclip: -f keeps it in the foreground serving
      # the selection, so the pipeline never sees EOF and both ends hang
      # (observed live 2026-06-11). Without -f xclip forks and returns.
      ${pkgs.coreutils}/bin/tee >(${pkgs.xclip}/bin/xclip -i -sel p) \
        | ${pkgs.xclip}/bin/xclip -i -sel c
    fi
  '';
  clipPaste = pkgs.writeShellScript "tmux-clip-paste" ''
    ${findWayland}
    if [ -n "$WAYLAND_DISPLAY" ]; then
      exec ${pkgs.wl-clipboard}/bin/wl-paste --primary
    else
      exec ${pkgs.xclip}/bin/xclip -o -sel p
    fi
  '';
in
{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    historyLimit = 100000;
    terminal = "tmux-256color";
    plugins = [
      { plugin = pkgs.tmuxPlugins.resurrect; }
      {
        plugin = pkgs.tmuxPlugins.continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
      { plugin = pkgs.tmuxPlugins.copycat; }
    ];

    extraConfig = ''

      ## COLORSCHEME: gruvbox dark
      set-option -g status "on"

      # default statusbar color
      set-option -g status-style bg=colour237,fg=colour223 # bg=bg1, fg=fg1

      # default window title colors
      set-window-option -g window-status-style bg=colour214,fg=colour237 # bg=yellow, fg=bg1

      set-window-option -g window-status-activity-style bg=colour237,fg=colour248 # bg=bg1, fg=fg3

      # active window title colors
      set-window-option -g window-status-current-style bg=red,fg=colour237 # fg=bg1

      # pane border
      set-option -g pane-active-border-style fg=colour250 #fg2
      set-option -g pane-border-style fg=colour237 #bg1

      # message infos
      set-option -g message-style bg=colour239,fg=colour223 # bg=bg2, fg=fg1

      # writing commands inactive
      set-option -g message-command-style bg=colour239,fg=colour223 # bg=fg3, fg=bg1

      # pane number display
      set-option -g display-panes-active-colour colour250 #fg2
      set-option -g display-panes-colour colour237 #bg1

      # clock
      set-window-option -g clock-mode-colour colour109 #blue

      # bell
      set-window-option -g window-status-bell-style fg=colour235,bg=colour167 # bg=red, fg=bg

      ## Theme settings mixed with colors (unfortunately, but there is no cleaner way)
      set-option -g status-justify "left"
      set-option -g status-left-style none
      set-option -g status-left-length "80"
      set-option -g status-right-style none
      set-option -g status-right-length "80"
      set-window-option -g window-status-separator ""

      set-option -g status-left "#{?client_prefix,#[fg=colour214 bg=colour241 bold],#[fg=colour248 bg=colour241]} #S #[fg=colour241, bg=colour237, nobold, noitalics, nounderscore]"
      set-option -g status-right "#[fg=colour239, bg=colour237, nobold, nounderscore, noitalics]#[fg=colour246,bg=colour239]  %H:%M  %d-%b-%Y #[fg=colour248, bg=colour239, nobold, noitalics, nounderscore] "

      set-window-option -g window-status-current-format "#[fg=colour237, bg=colour214, nobold, noitalics, nounderscore]#[fg=colour239, bg=colour214] #I #[fg=colour239, bg=colour214, bold] #W #[fg=colour214, bg=colour237, nobold, noitalics, nounderscore]"
      set-window-option -g window-status-format "#[fg=colour237,bg=colour239,noitalics]#[fg=colour223,bg=colour239] #I #[fg=colour223, bg=colour239] #W #[fg=colour239, bg=colour237, noitalics]"


      # switch windows alt+number
      bind-key -n M-1 select-window -t 1
      bind-key -n M-2 select-window -t 2
      bind-key -n M-3 select-window -t 3
      bind-key -n M-4 select-window -t 4
      bind-key -n M-5 select-window -t 5
      bind-key -n M-6 select-window -t 6
      bind-key -n M-7 select-window -t 7
      bind-key -n M-8 select-window -t 8
      bind-key -n M-9 select-window -t 9

      # Move to window
      bind-key -n M-h select-pane -L
      bind-key -n M-j select-pane -D
      bind-key -n M-k select-pane -U
      # bind-key -n M-l select-pane -R

      set -g mouse on

      set -g focus-events on

      set-option -g allow-rename off

      # Automatically re-number windows after one of them is closed
      set -g renumber-windows on

      # Pass xterm-style keys to make many key combinations work as expected
      setw -g xterm-keys on

      # Monitor window activity. Windows with activity are highlighted in the status line
      setw -g monitor-activity on

      # Reload Tmux configuration file with Prefix + r
      bind r source-file ~/.tmux.conf \; display "Configuration reloaded."

      # Getting interesting now, we use the vertical and horizontal
      # symbols to split the screen
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # New window with path as same as current path
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      bind-key -n M-z resize-pane -Z

      bind-key -n M-s split-window -v "${pkgs.tmux}/bin/tmux list-sessions | grep -v '(attached)$' | sed -E 's/:.*$//' | ${pkgs.fzf}/bin/fzf --reverse | ${pkgs.findutils}/bin/xargs ${pkgs.tmux}/bin/tmux switch-client -t"

      # Send the same command to all panes/windows/sessions
      bind E command-prompt -p "Command:" \
             "run \"${pkgs.tmux}/bin/tmux list-panes -a -F '##{session_name}:##{window_index}.##{pane_index}' \
                    | xargs -I PANE ${pkgs.tmux}/bin/tmux send-keys -t PANE '%1' Enter\""

      set-window-option -g visual-bell on
      set-window-option -g bell-action other


      ##########
      #
      # Copy paste with Emacs bindings for OSX
      #
      #
      # unbind -T copy-mode 'C-w'
      # unbind -T copy-mode 'M-w'
      # unbind -T copy-mode Enter
      #
      # bind-key -T copy-mode 'C-w' send -X
      #
      # bind-key -T copy-mode 'C-w' send -X copy-pipe-and-cancel "reattach-to-user-namespace pbcopy"
      # bind-key -T copy-mode 'M-w' send -X copy-pipe-and-cancel "reattach-to-user-namespace pbcopy"
      # bind-key -T copy-mode Enter send -X copy-pipe-and-cancel "reattach-to-user-namespace pbcopy"
      #
      #
      ##########

      ##########
      #
      # Copy paste with Emacs bindings for Linux
      #
      bind-key -n -T copy-mode 'C-w' send -X copy-pipe-and-cancel "${clipCopy}"
      bind-key -n -T copy-mode 'M-w' send -X copy-pipe-and-cancel "${clipCopy}"
      bind-key -n -T copy-mode Enter send -X copy-pipe-and-cancel "${clipCopy}"
      # Mouse-release copy must be bound explicitly: copycat installs its own
      # MouseDragEnd1Pane binding (copy-pipe-and-cancel with NO command, i.e.
      # tmux buffer only), and plugins load before extraConfig, so this
      # rebind wins. Bound in both key tables so it survives mode-keys
      # flipping to vi (tmux auto-selects vi when EDITOR contains "vi").
      bind-key -n -T copy-mode MouseDragEnd1Pane send -X copy-pipe-and-cancel "${clipCopy}"
      bind-key -n -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "${clipCopy}"
      bind-key -n C-y run "${clipPaste} | ${pkgs.tmux}/bin/tmux load-buffer - ; ${pkgs.tmux}/bin/tmux paste-buffer"
      #
      #
      ##########

      # WAYLAND_DISPLAY/SWAYSOCK: attaching from a sway terminal refreshes
      # the session env so new panes (and anything resolving env per-pane)
      # see the live compositor — the pre-warm server is born without them
      # (see the findWayland comment above and systemd.nix).
      set -g update-environment "DISPLAY SHELL SSH_ASKPASS SSH_AGENT_PID SSH_CONNECTION WINDOWID XAUTHORITY SSH_AUTH_SOCK WAYLAND_DISPLAY SWAYSOCK"
      # Pin a stable local agent socket so panes keep a working agent across
      # reattaches (belt-and-suspenders to update-environment above, which
      # already pulls the live value on attach). Sourced from home.nix's
      # SSH_AUTH_SOCK so there's one source of truth — switching agents
      # (currently gcr-ssh-agent, base.nix) only needs editing it once.
      set-environment -g SSH_AUTH_SOCK ${config.home.sessionVariables.SSH_AUTH_SOCK}

    '';
  };
}
