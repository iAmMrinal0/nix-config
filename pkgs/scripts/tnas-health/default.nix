{ writeShellScriptBin, openssh, coreutils }:

# Audit a TrueNAS box from the desktop: pool health, scrub schedule/age,
# SMART test coverage, per-disk SMART attributes, alert delivery, snapshot
# tasks. TrueNAS looks GUI-only but everything the GUI shows comes from the
# middleware, queryable as JSON via `midclt call` — remote.sh runs on the
# NAS and does exactly that (read-only throughout).
#
# The target host is deliberately not baked in: pass it as $1 or set
# TNAS_HOST. The payload is shipped base64-encoded so no quoting survives
# two shells; `sudo` on the far side because smartctl/midclt need root
# (ssh -t so it can prompt if the admin's sudo isn't passwordless).
# Exit code: 0 clean, 1 warnings, 2 failures — cron/timer friendly.
writeShellScriptBin "tnas-health" ''
  host="''${1:-''${TNAS_HOST:-}}"
  if [ -z "$host" ]; then
    echo "usage: tnas-health <ssh-host>  (or set TNAS_HOST)" >&2
    exit 64
  fi
  payload=$(${coreutils}/bin/base64 -w0 < ${./remote.sh})
  tty=""
  [ -t 0 ] && tty="-t"
  exec ${openssh}/bin/ssh $tty "$host" "echo $payload | base64 -d | sudo bash"
''
