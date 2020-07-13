{ pkgs, ... }:

with pkgs;

{
  enable = true;
  baseIndex = 1;
  clock24 = true;
  historyLimit = 100000;
  terminal = "screen-256color";
  plugins = with tmuxPlugins; [
    { plugin = resurrect; }
    { plugin = continuum; extraConfig = "set -g @continuum-restore 'on'"; }
    { plugin = copycat; }
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

bind-key -n M-s split-window -v "${tmux}/bin/tmux list-sessions | sed -E 's/:.*$//' | grep -v \"^$(${tmux}/bin/tmux display-message -p '#S')\$\" | ${fzf}/bin/fzf --reverse | ${findutils}/bin/xargs ${tmux}/bin/tmux switch-client -t"

# Send the same command to all panes/windows/sessions
bind E command-prompt -p "Command:" \
       "run \"${tmux}/bin/tmux list-panes -a -F '##{session_name}:##{window_index}.##{pane_index}' \
              | xargs -I PANE ${tmux}/bin/tmux send-keys -t PANE '%1' Enter\""

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
bind-key -n -T copy-mode 'C-w' send -X copy-pipe-and-cancel "${xclip}/bin/xclip -i -sel p -f | ${xclip}/bin/xclip -i -sel c "
bind-key -n -T copy-mode 'M-w' send -X copy-pipe-and-cancel "${xclip}/bin/xclip -i -sel p -f | ${xclip}/bin/xclip -i -sel c "
bind-key -n -T copy-mode Enter send -X copy-pipe-and-cancel "${xclip}/bin/xclip -i -sel p -f | ${xclip}/bin/xclip -i -sel c "
bind-key -n C-y run "${xclip}/bin/xclip -o | ${tmux}/bin/tmux load-buffer - ; ${tmux}/bin/tmux paste-buffer"
#
#
##########

set -g update-environment "DISPLAY SHELL SSH_ASKPASS SSH_AGENT_PID SSH_CONNECTION WINDOWID XAUTHORITY SSH_AUTH_SOCK"
set-environment -g SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent

'';
}
