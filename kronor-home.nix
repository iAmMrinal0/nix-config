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


    # This service has no display vars, so a pinentry spawned by the OTP
    # command (rbw's interactive fallback when the keyring path fails) dies
    # instantly. Overlay them from the user manager per request rather than
    # binding the unit to a graphical target: graphical-session.target goes
    # sticky across the i3/sway picker (see sway/config.nix), and a fresh
    # lookup also tracks WAYLAND_DISPLAY changing across sway restarts.
    def session_environment():
        env = dict(os.environ)
        try:
            shown = subprocess.run(
                ["${pkgs.systemd}/bin/systemctl", "--user", "show-environment"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
        except (OSError, subprocess.CalledProcessError):
            return env

        for line in shown.splitlines():
            name, separator, value = line.partition("=")
            if separator and name in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY"):
                env[name] = value

        return env


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
                    result = subprocess.run(
                        command,
                        check=False,
                        capture_output=True,
                        env=session_environment(),
                    )
                    if result.returncode != 0:
                        detail = result.stderr.decode("utf-8", "replace").strip()
                        print(
                            f"OTP command failed for {request_id} with status "
                            f"{result.returncode}"
                            + (f": {detail}" if detail else ""),
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

  namespaceRunner = nixosConfig.kronor.namespaceRunner;

  mkNamespaceExec = name: namespace: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.coreutils ];
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

      exec /run/wrappers/bin/sudo --preserve-env \
        ${namespaceRunner} ${namespace} "$command_path" "$@"
    '';
  };

  environments = nixosConfig.kronor.environments;

  # Speak SOCKS5 directly for the reply code: it distinguishes "the gateway
  # refused us" from "the gateway tried and nothing answered". A client cannot.
  socksProbe = pkgs.writeText "kronor-socks-probe.py" ''
    import socket
    import struct
    import sys

    proxy_port, host, port, timeout = (
        int(sys.argv[1]), sys.argv[2].encode(), int(sys.argv[3]), float(sys.argv[4])
    )

    REPLIES = {
        0: "reachable",
        1: "general SOCKS server failure",
        2: "connection not allowed by ruleset",
        3: "network unreachable",
        4: "host unreachable",
        5: "connection refused",
        6: "TTL expired",
        7: "command not supported",
        8: "address type not supported",
    }

    try:
        sock = socket.create_connection(("127.0.0.1", proxy_port), timeout=timeout)
    except OSError as error:
        print("gateway 127.0.0.1:%d unreachable: %s" % (proxy_port, error))
        sys.exit(2)

    try:
        sock.settimeout(timeout)
        sock.sendall(b"\x05\x01\x00")
        greeting = sock.recv(2)
        if len(greeting) < 2 or greeting[0] != 5:
            print("gateway closed the connection without negotiating (dante ACL?)")
            sys.exit(2)
        if greeting[1] != 0:
            print("gateway rejected the no-auth method (dante ACL?)")
            sys.exit(2)

        sock.sendall(
            b"\x05\x01\x00\x03" + bytes([len(host)]) + host + struct.pack("!H", port)
        )
        reply = sock.recv(4)
        if len(reply) < 2:
            print("gateway gave no reply (dante ACL?)")
            sys.exit(2)

        code = reply[1]
        print(REPLIES.get(code, "unknown SOCKS reply %d" % code))
        sys.exit(0 if code == 0 else 1)
    except socket.timeout:
        print("no reply in %.0fs -- dropped past the gateway" % timeout)
        sys.exit(1)
    except OSError as error:
        # A reset mid-negotiation is dante hanging up on us, not a dead target.
        print("gateway hung up mid-negotiation (dante ACL?): %s" % error)
        sys.exit(2)
    finally:
        sock.close()
  '';

  kronorCli = pkgs.writeShellApplication {
    name = "kronor";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # Absolute paths: the sudoers rule in kronor.nix matches on this exact
      # systemctl path, and sudo has to be the setuid wrapper.
      systemctl=/run/current-system/sw/bin/systemctl
      journalctl=/run/current-system/sw/bin/journalctl
      sudo=/run/wrappers/bin/sudo

      usage() {
        cat >&2 <<'USAGE'
      usage: kronor <env> <command>

        env:      production | staging   (prod, stg accepted too)
        command:  start       bring the tunnel up and hold it open
                  stop        drop the tunnel
                  status      show what is up
                  check       probe every layer and say which one is broken
                  logs        journal for this environment's units
                  shell       shell running inside this environment
                  run <cmd>   one command inside this environment (staging only)
      USAGE
        exit 2
      }

      (( $# >= 1 )) || usage

      case "$1" in
        prod|production) environment=production ;;
        staging|stg) environment=staging ;;
        -h|--help|help) usage ;;
        *) echo "kronor: unknown environment: $1" >&2; usage ;;
      esac
      shift

      case "$environment" in
        ${lib.concatStringsSep "\n        " (lib.mapAttrsToList (environment: endpoints:
          "${environment}) socks_port=${toString endpoints.socksPort}; dns_address=${endpoints.dnsAddress} ;;")
          environments)}
      esac

      # Resolving it exercises the DNS socket; connecting exercises the tunnel.
      check_host="primary.psql.internal.$environment.kronor.io"

      unit() { echo "kronor-$environment-$1.service"; }

      active() { [[ "$("$systemctl" is-active "$1" || true)" == active ]]; }

      show_status() {
        local since held
        since=$("$systemctl" show -P ActiveEnterTimestamp "$(unit vpn)" 2>/dev/null || true)
        if active "$(unit pin)"; then held=yes; else held="no (idles out after 10m)"; fi

        printf '%-8s %s\n' "env" "$environment"
        if active "$(unit vpn)"; then
          printf '%-8s %s\n' "tunnel" "up''${since:+ since $since}"
        else
          printf '%-8s %s\n' "tunnel" "down"
        fi
        printf '%-8s %s\n' "held" "$held"
        printf '%-8s %s\n' "socks" "127.0.0.1:$socks_port"
      }

      row() { printf '  %-9s %-5s %s\n' "$2" "$1" "$3"; }

      tunnel_address() {
        # openvpn logs the address with its prefix ("192.168.235.5/24"), so the
        # match stops at the slash; || true keeps a miss from ending the check.
        "$journalctl" -u "$(unit vpn)" -n 300 --no-pager 2>/dev/null \
          | grep -oE 'net_addr_v4_add: [0-9.]+' | tail -1 | cut -d' ' -f2 || true
      }

      # Ordered outwards: the first FAIL is the layer to fix.
      run_check() {
        local failed=0 namespace="kronor-$environment" address answer probe held

        if [[ -e "/run/netns/$namespace" ]] && active "netns-$namespace.service"; then
          row ok netns "$namespace"
        else
          row FAIL netns "sudo systemctl start netns-$namespace.service"
          failed=1
        fi

        if ! active "$(unit vpn)"; then
          # Probing further would start the tunnel, for a command that reports.
          row down tunnel "run: kronor $environment start"
          row skip dns "tunnel down"
          row skip socks "tunnel down"
          return 1
        fi

        address=$(tunnel_address)
        if active "$(unit pin)"; then held=held; else held="idles out after 10m"; fi
        row ok tunnel "''${address:-address unknown} ($held)"

        if active "$(unit socks)"; then
          row ok dante "gateway 127.0.0.1:$socks_port"
        else
          row FAIL dante "not running -- see: kronor $environment logs"
          failed=1
        fi

        if answer=$(${pkgs.dnsutils}/bin/dig +tcp +time=5 +tries=1 +short \
              "@$dns_address" "$check_host" 2>/dev/null) && [[ -n "$answer" ]]; then
          row ok dns "$check_host -> $(echo "$answer" | tail -1)"
        else
          row FAIL dns "no answer from $dns_address (TCP :53)"
          failed=1
        fi

        if [[ -n "''${KRONOR_ENV:-}" ]]; then
          # 127.0.0.1 in here is the namespace's own loopback; the gateway
          # listens on the host's, so a probe from here says nothing.
          row skip "tcp 5432" "gateway is host-side; check from a host shell"
        elif probe=$(${pkgs.python3}/bin/python ${socksProbe} "$socks_port" "$check_host" 5432 8 2>&1); then
          row ok "tcp 5432" "$probe"
        else
          row FAIL "tcp 5432" "$probe"
          failed=1
        fi

        return "$failed"
      }

      case "''${1-}" in
        start)
          # The pin pulls in the VPN unit; the OTP comes from rbw, so no prompt.
          "$sudo" "$systemctl" start "$(unit pin)"
          show_status
          ;;
        stop)
          "$sudo" "$systemctl" stop "$(unit pin)"
          "$sudo" "$systemctl" stop "$(unit vpn)"
          show_status
          ;;
        status)
          show_status
          ;;
        check)
          run_check
          ;;
        logs)
          shift
          (( $# >= 1 )) || set -- -n 100
          exec "$journalctl" \
            -u "$(unit vpn)" -u "$(unit dns)" -u "$(unit socks)" \
            -u "$(unit browser)" -u "$(unit pin)" \
            -u "netns-kronor-$environment.service" \
            "$@"
          ;;
        run)
          shift
          (( $# >= 1 )) || usage
          # Staging only: a one-shot this easy to script is exactly what
          # production should not have. Humans have nkp, agents have MCP.
          if [[ "$environment" != staging ]]; then
            echo "kronor: run is staging-only by design; for production use" \
              "nkp <command>, or the kronor-production MCP server" >&2
            exit 2
          fi

          active "$(unit vpn)" || "$sudo" "$systemctl" start "$(unit pin)"
          command_path=$(command -v "$1") || {
            echo "kronor: command not found: $1" >&2
            exit 127
          }
          shift
          exec "$sudo" --preserve-env ${namespaceRunner} "kronor-$environment" \
            ${pkgs.coreutils}/bin/env KRONOR_ENV="$environment" \
            "$command_path" "$@"
          ;;
        shell)
          # Start first: inside the namespace a command that never resolves a
          # name (ping, ip) would not socket-activate the tunnel on its own.
          active "$(unit vpn)" || "$sudo" "$systemctl" start "$(unit pin)"
          echo "kronor: $environment shell -- every command runs inside the" \
            "namespace; exit to leave" >&2
          exec "$sudo" --preserve-env ${namespaceRunner} "kronor-$environment" \
            ${pkgs.coreutils}/bin/env KRONOR_ENV="$environment" \
            "''${SHELL:-${pkgs.zsh}/bin/zsh}"
          ;;
        *) usage ;;
      esac
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
    kronorCli
    connectKronorVpn
    (mkNamespaceExec "nks" "kronor-staging")
    (mkNamespaceExec "nkp" "kronor-production")
  ];

  # Route psql/pgcli through the matching namespace when any argument
  # targets an internal Kronor host, so old history entries work unprefixed.
  programs.zsh.initContent = ''
    # Unexported on purpose: direnv rewrites the environment on cd (the
    # wagabooga devshell drops KRONOR_ENV) and would silently blank this.
    typeset -g _kronor_shell_env="''${KRONOR_ENV:-}"

    _kronor_netns_dispatch() {
      local cmd=$1; shift
      # The shell already runs inside the namespace; nothing left to wrap.
      if [[ -n "$_kronor_shell_env" ]]; then
        command "$cmd" "$@"
        return
      fi
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

    _kronor() {
      if (( CURRENT == 2 )); then
        # Canonical only: offering prod as well would stall `kronor p<TAB>`.
        compadd production staging
      elif (( CURRENT == 3 )); then
        # run is staging-only, so do not advertise it under production
        local -a cmds=(start stop status check logs shell)
        [[ $words[2] != (prod|production) ]] && cmds+=run
        compadd -- $cmds
      elif [[ $words[3] == run ]]; then
        # Three precommand words, not two, or _normal completes for a command
        # called "run"; -p then drops builtins, which `env <path>` cannot run.
        shift 3 words; (( CURRENT -= 3 )); _normal -p kronor
      fi
    }
    compdef _kronor kronor
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
