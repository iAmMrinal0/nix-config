{ lib, stdenv, writeShellScriptBin, jq, upower, jc }:

writeShellScriptBin "bluetooth-battery" ''
  devices='[
    {"device":"WH-1000XM3","serial":"CC:98:8B:F5:09:D3","icon":""},
    {"device":"LE_WH-1000XM3","serial":"CC:98:8B:F5:09:D3","icon":""}
  ]'

  # Iterate over each device in the JSON array
  for row in $(echo "$devices" | jq -c '.[]'); do
    model=$(echo "$row" | ${jq}/bin/jq -r '.device')
    serial=$(echo "$row" | ${jq}/bin/jq -r '.serial')
    icon=$(echo "$row" | ${jq}/bin/jq -r '.icon')

    # Get the charge percentage for the current device
    CHARGE=$(${upower}/bin/upower --dump | ${jc}/bin/jc --upower | ${jq}/bin/jq -c --arg device "$model" --arg serial "$serial" \
      '.[] | select(.model==$device and .serial==$serial).detail.percentage | floor')

    # Check if the charge percentage is valid and print it with icon
    if [[ $CHARGE =~ ^[0-9]+$ ]] && (( CHARGE >= 0 && CHARGE <= 100 )); then
      echo "$icon $CHARGE%"
      break  # Exit after finding the charge for the first matched device
    fi
  done

  # If no valid charge was found, print "Off"
  if [[ -z $CHARGE ]] || (( CHARGE < 0 || CHARGE > 100 )); then
    echo "Off"
  fi
''
