{ pkgs, ... }:

pkgs.writeShellScript "bluetooth_battery" ''
  DEVICE=$(${pkgs.bluez}/bin/bluetoothctl info | grep -o "[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]" | head -1)
  CHARGE=$(${pkgs.python3.withPackages (ps: [ ps.pybluez ])}/bin/python3 ${./bluetooth_battery.py} $DEVICE)
  if (( CHARGE >= 0 && CHARGE <= 100 )); then
    echo " "$CHARGE"%"
  else
    echo " Off"
  fi
''
