{ writeShellScriptBin, kanshi, rofi, gnugrep, libnotify, sway, jq }:

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

  # On failure, show kanshictl's error plus each head's make/model/serial:
  # kanshi 1.8+ fnmatch()es profile criteria against "make model serial", so a
  # refused switch is almost always a criteria/description mismatch that is
  # otherwise invisible.
  if err=$(${kanshi}/bin/kanshictl switch "$selected" 2>&1); then
    ${sway}/bin/swaymsg 'output * power on' >/dev/null 2>&1 || true
    ${libnotify}/bin/notify-send "Kanshi" "Switched to $selected"
  else
    heads=$(${sway}/bin/swaymsg -t get_outputs 2>/dev/null |
      ${jq}/bin/jq -r '.[] | "\(.name): \(.make) \(.model) \(.serial)"')
    ${libnotify}/bin/notify-send -u critical "Kanshi" "Failed to switch to $selected
$err
heads:
$heads"
  fi
''
