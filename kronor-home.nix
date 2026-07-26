{ config, nixosConfig, pkgs, lib, ... }:

let
  user = config.home.username;
  userHome = config.home.homeDirectory;
  otpCommands = {
    "kronor-vpn:staging" = [ "${pkgs.rbw}/bin/rbw" "code" "pritunl staging" ];
    "kronor-vpn:production" = [ "${pkgs.rbw}/bin/rbw" "code" "pritunl prod" ];
  };
  otpCommandsFile = pkgs.writeText "kronor-otp-commands.json" (builtins.toJSON otpCommands);
  otpAgent = pkgs.writeText "kronor-otp-agent.py" ''
    import configparser
    import json
    import os
    from pathlib import Path
    import socket
    import subprocess
    import sys
    import time


    def reply(address, payload):
        if address.startswith("@"):
            address = "\0" + address[1:]

        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
            sock.sendto(payload, address)


    with open(sys.argv[1], encoding="utf-8") as commands_file:
        commands = json.load(commands_file)

    request_directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "systemd/ask-password"
    handled = set()

    while True:
        active = set()
        if request_directory.is_dir():
            for request in request_directory.glob("ask.*"):
                try:
                    request_key = (request, request.stat().st_ino)
                    active.add(request_key)
                    if request_key in handled:
                        continue

                    parser = configparser.ConfigParser(interpolation=None)
                    parser.read(request)
                    ask = parser["Ask"]
                    request_id = ask.get("Id", "")
                    command = commands.get(request_id)
                    if command is None:
                        continue

                    handled.add(request_key)
                    result = subprocess.run(command, check=False, capture_output=True)
                    if result.returncode != 0:
                        print(
                            f"OTP command failed for {request_id} with status "
                            f"{result.returncode}",
                            file=sys.stderr,
                            flush=True,
                        )
                        reply(ask["Socket"], b"-")
                        continue

                    password = result.stdout.rstrip(b"\r\n")
                    if not password or b"\0" in password:
                        print(f"OTP command returned invalid output for {request_id}", file=sys.stderr)
                        reply(ask["Socket"], b"-")
                        continue

                    reply(ask["Socket"], b"+" + password)
                except (FileNotFoundError, KeyError, OSError, configparser.Error) as error:
                    print(f"Unable to process {request}: {error}", file=sys.stderr, flush=True)

        handled.intersection_update(active)
        time.sleep(0.2)
  '';

  mkNamespaceExec = name: namespace: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.coreutils pkgs.iproute2 pkgs.util-linux ];
    text = ''
      if (( $# == 0 )); then
        echo "usage: ${name} <command> [arguments...]" >&2
        exit 2
      fi

      command_path=$(command -v "$1") || {
        echo "${name}: command not found: $1" >&2
        exit 127
      }
      shift

      exec sudo --preserve-env ip netns exec ${namespace} \
        ${pkgs.writeShellScript "${name}-namespace-exec" ''
          # Keep glibc from sending namespace lookups to the host nscd.
          ${pkgs.util-linux}/bin/mount \
            -t tmpfs \
            -o mode=755,nosuid,nodev \
            tmpfs /run/nscd

          # --regid needs the user's group, which is not named after the
          # user here (primary group: users).
          gid=$(${pkgs.coreutils}/bin/id -g ${user})

          exec ${pkgs.util-linux}/bin/setpriv \
            --reuid=${user} --regid="$gid" --init-groups \
            ${pkgs.coreutils}/bin/env \
              HOME=${userHome} USER=${user} LOGNAME=${user} \
              "$@"
        ''} \
        "$command_path" "$@"
    '';
  };

  connectKronorVpn = pkgs.writeShellApplication {
    name = "connect-kronor-vpn";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
      pkgs.openvpn
      pkgs.rbw
    ];
    text = ''
      credentials=$(mktemp)
      trap 'rm -f "$credentials"' EXIT
      printf '%s\n' "mrinal@kronor.io" > "$credentials"

      case "''${1:-staging}" in
        staging)
          rbw code "pritunl staging" >> "$credentials"
          namespace=kronor-staging
          vpn_config=${nixosConfig.sops.secrets.kronor-openvpn-staging.path}
          ;;
        production)
          rbw code "pritunl prod" >> "$credentials"
          namespace=kronor-production
          vpn_config=${nixosConfig.sops.secrets.kronor-openvpn-production.path}
          ;;
        *)
          echo "usage: connect-kronor-vpn [staging|production]" >&2
          exit 2
          ;;
      esac

      sudo ip netns exec "$namespace" openvpn \
        --config "$vpn_config" \
        --auth-user-pass "$credentials"
    '';
  };
in
{
  home.packages = [
    connectKronorVpn
    (mkNamespaceExec "nks" "kronor-staging")
    (mkNamespaceExec "nkp" "kronor-production")
  ];

  programs.bash.bashrcExtra = lib.mkAfter ''
    if declare -F _command >/dev/null; then
      complete -F _command nks nkp
    fi
  '';

  # Route psql/pgcli through the matching namespace when any argument
  # targets an internal Kronor host, so old history entries work unprefixed.
  programs.zsh.initContent = ''
    _kronor_netns_dispatch() {
      local cmd=$1; shift
      local target="$*"
      # service=NAME hides the host in pg_service.conf; resolve it for matching
      if [[ "$target" =~ 'service=([A-Za-z0-9_-]+)' ]]; then
        target+=" $(awk -F= -v s="[$match[1]]" '$0 == s { f = 1; next } /^\[/ { f = 0 } f && $1 == "host" { print $2; exit }' \
          "''${PGSERVICEFILE:-$HOME/.pg_service.conf}" 2>/dev/null)"
      fi
      # pgcli -D ALIAS hides it in the pgclirc's [alias_dsn] section
      local -a args=("$@")
      local i dsn_alias="" rc="''${XDG_CONFIG_HOME:-$HOME/.config}/pgcli/config"
      for (( i = 1; i <= $#args; i++ )); do
        case "$args[i]" in
          -D|--dsn) dsn_alias="$args[i+1]" ;;
          --dsn=*) dsn_alias="''${args[i]#--dsn=}" ;;
          --pgclirc) rc="$args[i+1]" ;;
          --pgclirc=*) rc="''${args[i]#--pgclirc=}" ;;
        esac
      done
      if [[ -n "$dsn_alias" ]]; then
        target+=" $(awk -F' *= *' -v a="$dsn_alias" \
          '$0 == "[alias_dsn]" { f = 1; next } /^\[/ { f = 0 } f && $1 == a { print $2; exit }' \
          "$rc" 2>/dev/null)"
      fi
      case "$target" in
        *.internal.staging.kronor.io*) nks "$cmd" "$@" ;;
        *.internal.production.kronor.io*) nkp "$cmd" "$@" ;;
        *) command "$cmd" "$@" ;;
      esac
    }
    psql() { _kronor_netns_dispatch psql "$@" }
    pgcli() { _kronor_netns_dispatch pgcli "$@" }
  '';

  programs.firefox.policies.Proxy = {
    Mode = "autoConfig";
    AutoConfigURL = "http://127.0.0.1:11090/kronor.pac";
    UseProxyForDNS = true;
    Locked = true;
  };

  systemd.user.services.kronor-otp-agent = {
    Unit.Description = "Kronor VPN OTP agent";
    Service = {
      ExecStart = "${pkgs.python3}/bin/python ${otpAgent} ${otpCommandsFile}";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
