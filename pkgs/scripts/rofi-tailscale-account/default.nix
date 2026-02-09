{ writeShellScriptBin, tailscale, rofi, gawk, libnotify }:

writeShellScriptBin "rofi-tailscale-account" ''
  accounts=$(${tailscale}/bin/tailscale switch --list 2>/dev/null | tail -n +2 | ${gawk}/bin/awk '{print $3}')
  [ -z "$accounts" ] && exit 1

  selected=$(echo -e "$accounts" | ${rofi}/bin/rofi -dmenu -i -p "Account")
  [ -z "$selected" ] && exit 0

  account_name=$(echo "$selected" | sed 's/\*$//')
  if ${tailscale}/bin/tailscale switch "$account_name"; then
      ${libnotify}/bin/notify-send "Tailscale" "Switched to $account_name"
  else
      ${libnotify}/bin/notify-send -u critical "Tailscale" "Failed to switch to $account_name"
  fi
''
