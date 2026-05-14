{ pkgs, lib, username, ... }:

let
  mkRcloneMountService = { name, description, remote, mountPath
    , cacheDir ? "/home/${username}/.cache/rclone/${name}" }: {
      "rclone-${name}-mount" = {
        Unit = {
          Description = description;
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
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
            # Starts a session named after the user rooted in $HOME (same
            # shape continuum already restores). Starting the server here
            # also triggers continuum auto-restore in the background so the
            # first `tmuxdir` call is fast.
            ExecStart =
              "${pkgs.tmux}/bin/tmux new-session -d -s ${username} -c %h";
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
