{ writeShellScriptBin, kanshi, rofi, gnugrep, libnotify, sway }:

# Sway equivalent of rofi-autorandr: lists kanshi profiles defined in
# ~/.config/kanshi/config and switches via `kanshictl switch`. Profile
# names are parsed from `profile <name> {` lines so the script auto-picks up
# any profiles the host's kanshi config defines. (home-manager's
# services.kanshi writes the generated config to ~/.config/kanshi/config —
# no .kdl extension — so that's the path we read.)
#
# After a successful switch we also force `output * power on`. kanshi's
# modeset reports success even when an output is in a DPMS/power-off state
# (e.g. a monitor hotplugged while the session was idle/locked): the config
# is accepted but no mode commits, leaving the panel dark at current_mode
# 0x0. Re-powering is a no-op for already-on outputs and is the manual
# recovery for exactly the case this script exists to handle.
writeShellScriptBin "rofi-kanshi" ''
  config="''${XDG_CONFIG_HOME:-$HOME/.config}/kanshi/config"
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
    ${sway}/bin/swaymsg 'output * power on' >/dev/null 2>&1 || true
    ${libnotify}/bin/notify-send "Kanshi" "Switched to $selected"
  else
    ${libnotify}/bin/notify-send -u critical "Kanshi" "Failed to switch to $selected"
  fi
''
