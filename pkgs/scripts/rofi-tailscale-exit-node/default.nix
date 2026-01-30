{ writeShellScriptBin, tailscale, rofi, gawk, gnugrep, libnotify, jq, gnused }:

writeShellScriptBin "rofi-tailscale-exit-node" ''
  current_ip=$(${tailscale}/bin/tailscale status --json | ${jq}/bin/jq -r '.ExitNodeStatus.TailscaleIPs[0] // ""' | ${gnused}/bin/sed 's|/.*||')

  options=$(${tailscale}/bin/tailscale exit-node list | ${gnugrep}/bin/grep -v -e offline -e '^#' -e HOSTNAME | ${gawk}/bin/awk -v current="$current_ip" 'NF {if ($1 == current) print $2" ("$1") *"; else print $2" ("$1")"}')

  selected=$(echo -e "None\n$options" | ${rofi}/bin/rofi -dmenu -i -p "Exit Node")
  [ -z "$selected" ] && exit 0

  if [[ "$selected" == "None" ]]; then
      if ${tailscale}/bin/tailscale set --exit-node=; then
          ${libnotify}/bin/notify-send "Tailscale" "Exit node disabled"
      else
          ${libnotify}/bin/notify-send -u critical "Tailscale" "Failed to disable exit node"
      fi
  else
      ip=$(echo "$selected" | ${gnugrep}/bin/grep -oP '\(\K[^)]+')
      hostname=$(echo "$selected" | sed 's/ (.*//')
      if ${tailscale}/bin/tailscale set --exit-node="$ip"; then
          ${libnotify}/bin/notify-send "Tailscale" "Connected to $hostname"
      else
          ${libnotify}/bin/notify-send -u critical "Tailscale" "Failed to connect to $hostname"
      fi
  fi
''
