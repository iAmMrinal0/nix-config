{ writeShellScriptBin, autorandr, rofi }:

writeShellScriptBin "rofi-autorandr" ''
  # Mirror the flags used by the zsh `autorandr` alias and the udev service:
  # --match-edid binds profiles to monitors by EDID (so the DisplayLink dock's
  # USB enumeration order doesn't put the wrong panel in each slot), and
  # --skip-options crtc,gamma drops stale per-output state from older profiles.
  flags="--match-edid --skip-options crtc,gamma"
  # List *all* configured profiles (--list), not just the --detected ones: once
  # you unplug the dock the previously-active setup no longer matches any EDID,
  # so --detected would hide the very profile (e.g. default) you want to switch
  # to. The EDID-matching flags still apply on --load below.
  layout=$(${autorandr}/bin/autorandr --list | ${rofi}/bin/rofi -dmenu -p "Layout")
  [ -n "$layout" ] && ${autorandr}/bin/autorandr $flags --load "$layout"
''
