{ pkgs, config, ... }:

let
  # Runtime-dispatching clipboard wrappers: pick wl-clipboard under Wayland,
  # xclip under X11. Lets the same tmux config work under both the sway
  # (Wayland) and i3 (X11) session picks without conditional nix.
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

    # Theme, keybindings, splits and activity settings are shared with the
    # NixOS server profile via modules/tmux-common.nix; only the desktop-
    # specific bits (config-reload path, clipboard wrappers, SSH agent pin)
    # stay here.
    extraConfig = (import ../tmux-common.nix { inherit pkgs; }) + ''

      # Reload Tmux configuration file with Prefix + r
      # path derived from xdg.configHome so it can't drift from where HM writes it
      bind r source-file ${config.xdg.configHome}/tmux/tmux.conf \; display "Configuration reloaded."


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

      # Mouse-capturing TUIs (Claude Code etc.) bypass tmux's drag-copy and
      # set the clipboard themselves via OSC52. The default set-clipboard
      # "external" relies on tmux forwarding the escape to the outer
      # terminal — flaky here (pane-visibility gates, races). "on" makes
      # tmux ACCEPT the OSC52 into a paste buffer and fire the
      # pane-set-clipboard hook, which pipes it through the same wrapper as
      # every other copy. Deterministic, works from any pane in any
      # session, attached or not (verified live 2026-06-11).
      set -g set-clipboard on
      set-hook -g pane-set-clipboard 'run-shell "${pkgs.tmux}/bin/tmux show-buffer | ${clipCopy}"'
      #
      #
      ##########

      # Pin a stable local agent socket so panes keep a working agent across
      # reattaches (belt-and-suspenders to update-environment in tmux-common,
      # which already pulls the live value on attach). Sourced from home.nix's
      # SSH_AUTH_SOCK so there's one source of truth — switching agents
      # (currently gcr-ssh-agent, base.nix) only needs editing it once.
      set-environment -g SSH_AUTH_SOCK ${config.home.sessionVariables.SSH_AUTH_SOCK}
    '';
  };
}
