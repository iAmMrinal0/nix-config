{ pkgs, polybar, ... }:

pkgs.writeShellScript "polybarLaunch" ''
  # If all your bars have ipc enabled, you can also use
  ${polybar}/bin/polybar-msg cmd quit

  # Launch bar1 and bar2
  echo "---" | ${pkgs.coreutils}/bin/tee -a /tmp/polybar1.log /tmp/polybar2.log
  polybar top 2>&1 | ${pkgs.coreutils}/bin/tee -a /tmp/polybar1.log & disown
  polybar bottom 2>&1 | ${pkgs.coreutils}/bin/tee -a /tmp/polybar2.log & disown

  echo "Bars launched..."
''
