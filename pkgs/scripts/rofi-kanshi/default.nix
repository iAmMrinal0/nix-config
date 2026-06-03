{ writeShellScriptBin, kanshi, rofi, gnugrep, libnotify }:

# Sway equivalent of rofi-autorandr: lists kanshi profiles defined in
# ~/.config/kanshi/config.kdl and switches via `kanshictl switch`. Profile
# names are parsed from `profile <name> {` lines so the script auto-picks up
# any profiles the host's kanshi config defines.
writeShellScriptBin "rofi-kanshi" ''
  config="''${XDG_CONFIG_HOME:-$HOME/.config}/kanshi/config.kdl"
  if [ ! -r "$config" ]; then
    ${libnotify}/bin/notify-send -u critical "Kanshi" "No config at $config"
    exit 1
  fi

  profiles=$(${gnugrep}/bin/grep -oP '^profile\s+\K\S+' "$config" | sort -u)
  if [ -z "$profiles" ]; then
    ${libnotify}/bin/notify-send "Kanshi" "No profiles found in $config"
    exit 1
  fi

  selected=$(echo "$profiles" | ${rofi}/bin/rofi -dmenu -i -p "Layout")
  [ -z "$selected" ] && exit 0

  if ${kanshi}/bin/kanshictl switch "$selected"; then
    ${libnotify}/bin/notify-send "Kanshi" "Switched to $selected"
  else
    ${libnotify}/bin/notify-send -u critical "Kanshi" "Failed to switch to $selected"
  fi
''
