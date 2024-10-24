{ pkgs, ... }:

pkgs.writeShellScript "bluetooth_battery" ''
  devices='[
    {"device":"WH-1000XM3","serial":"CC:98:8B:F5:09:D3"},
    {"device":"WH-1000XM4","serial":"CC:98:8B:F5:09:D4"}
  ]'

  # Iterate over each device in the JSON array
  for row in $(echo "$devices" | jq -c '.[]'); do
    model=$(echo "$row" | ${pkgs.jq}/bin/jq -r '.device')
    serial=$(echo "$row" | ${pkgs.jq}/bin/jq -r '.serial')

    # Get the charge percentage for the current device
    CHARGE=$(${pkgs.upower}/bin/upower --dump | ${pkgs.jc}/bin/jc --upower | ${pkgs.jq}/bin/jq -c --arg device "$model" --arg serial "$serial" \
      '.[] | select(.model==$device and .serial==$serial).detail.percentage | floor')

    # Check if the charge percentage is valid and print it
    if [[ $CHARGE =~ ^[0-9]+$ ]] && (( CHARGE >= 0 && CHARGE <= 100 )); then
      echo "$CHARGE%"
      break  # Exit after finding the charge for the first matched device
    fi
  done

  # If no valid charge was found, print "Off"
  if [[ -z $CHARGE ]] || (( CHARGE < 0 || CHARGE > 100 )); then
    echo "Off"
  fi
''
