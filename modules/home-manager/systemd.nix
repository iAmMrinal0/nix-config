{ pkgs, lib, username, ... }:

let
  mkRcloneMountService = { name, description, remote, mountPath
    , cacheDir ? "/home/${username}/.cache/rclone/${name}" }: {
      "rclone-${name}-mount" = {
        Unit = {
          Description = description;
          # rclone-config.service (programs.rclone, modules/rclone.nix)
          # renders ~/.config/rclone/rclone.conf; the mount can't start
          # until the remote it names exists in that file.
          After = [ "network-online.target" "rclone-config.service" ];
          Wants = [ "network-online.target" "rclone-config.service" ];
        };

        Install = { WantedBy = [ "default.target" ]; };

        Service = {
          Type = "simple";

          # Ensure mount path and cache directory exist
          ExecStartPre = ''
            /run/current-system/sw/bin/mkdir -p ${mountPath} ${cacheDir}
          '';

          ExecStart = ''
            ${pkgs.rclone}/bin/rclone mount \
              --vfs-cache-mode full \
              --vfs-cache-max-age 24h \
              --vfs-cache-max-size 10G \
              --cache-dir ${cacheDir} \
              --allow-non-empty \
              ${remote}: ${mountPath}
          '';

          ExecStop = "/run/current-system/sw/bin/fusermount -u ${mountPath}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = [ "PATH=/run/wrappers/bin/:$PATH" ];
        };
      };
    };
in {
  systemd.user = {
    startServices = true;
    services = lib.mkMerge [
      (mkRcloneMountService {
        name = "gdrive";
        description = "Google Drive mount";
        remote = "gdrive";
        mountPath = "/home/${username}/gdrive";
      })

      (mkRcloneMountService {
        name = "tdrive";
        description = "WebDAV tailscale taildrive mount";
        remote = "tdrive";
        mountPath = "/home/${username}/tdrive";
      })

      { # Start tmux server at login so continuum auto-restore runs in the
        # background. Without this, the first `tmuxdir` invocation has to
        # boot the server, which triggers a full continuum restore of all
        # saved panes/sessions before returning.
        tmux-server = {
          Unit = {
            Description = "tmux server (pre-warm for continuum restore)";
          };
          Install = { WantedBy = [ "default.target" ]; };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            # The tmux SERVER lives in this unit's cgroup. If the unit ever
            # fails or is stopped/restarted (e.g. by HM on rebuild), the
            # default KillMode=control-group would kill the server and all
            # restored sessions with it. KillMode=process only touches the
            # main process (already exited for oneshot), leaving the server
            # alone.
            KillMode = "process";
            # Pin the socket dir to the one interactive shells use. The X
            # session carries TMUX_TMPDIR=/run/user/1000; the systemd user
            # manager (a sibling tree) does NOT, so tmux here defaulted to
            # /tmp/tmux-1000 — a separate server. The pre-warm restored onto
            # /tmp (unused) while the first interactive `tmuxdir` booted a cold
            # /run server and paid the full restore. %t = XDG_RUNTIME_DIR
            # (=/run/user/1000), matching the interactive value.
            #
            # DISPLAY/XAUTHORITY: this unit boots the server, but the systemd
            # user manager only learns DISPLAY/XAUTHORITY later, when the X
            # session runs `dbus-update-activation-environment` in
            # sessionCommands (modules/nixos/xserver.nix). That import races —
            # and loses to — this unit, so without these the server's global
            # env has no DISPLAY/XAUTHORITY and GUI apps launched from any pane
            # (notably vscode-fhs `code .`) hang / fail to create a window. Set
            # them statically: both are stable on this single-seat laptop
            # (DISPLAY=:0, ~/.Xauthority). The server is then "born correct" —
            # continuum's restore spawns pane shells that inherit a populated
            # global env. update-environment (tmux.nix) still lets a real X
            # client attach override the session env for new panes.
            Environment = [
              "TMUX_TMPDIR=%t"
              "DISPLAY=:0"
              "XAUTHORITY=/home/${username}/.Xauthority"
            ];
            # Boot the server and ensure the ${username} session exists.
            # new-session triggers the server boot, which sources tmux.conf
            # and runs continuum's auto-restore — that restore may itself
            # recreate '${username}' from the snapshot first, making our
            # create fail with "duplicate session"; has-session treats that
            # as success. Plain `-A` doesn't work here: with an existing
            # session it switches to attach-session, which needs a TTY that
            # services don't have ("open terminal failed: not a terminal").
            ExecStart = pkgs.writeShellScript "tmux-prewarm" ''
              ${pkgs.tmux}/bin/tmux new-session -d -s ${username} -c "$HOME" 2>/dev/null \
                || ${pkgs.tmux}/bin/tmux has-session -t ${username}
            '';
          };
        };
      }

      { # for bitwarden desktop app to unlock via system authentication
        polkit-gnome-authentication-agent-1 = {
          Unit = {
            Description = "polkit-gnome-authentication-agent-1";
            Wants = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Install = { WantedBy = [ "graphical-session.target" ]; };
          Service = {
            Type = "simple";
            ExecStart =
              "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };
        };
      }
    ];
  };
}
