{ writeShellScriptBin, ddcutil, libnotify }:

# Hand the home Dell U2724DE (and its KVM'd peripherals) to the other laptop
# by toggling the monitor's input over DDC/CI: USB-C 0x19 = cardassia, DP
# 0x0f = betazed. Run from whichever machine currently has the screen; the
# confirmation lands on the laptop panel. 0x19 is Dell's USB-C code, missing
# from ddcutil's MCCS table — full getvcp prints it as "Invalid value", but
# the terse form still carries the raw value.
writeShellScriptBin "kvm-switch" ''
  cur=$(${ddcutil}/bin/ddcutil --model "DELL U2724DE" -t getvcp 60 2>/dev/null) || {
    ${libnotify}/bin/notify-send -u critical "kvm-switch" "U2724DE not reachable over DDC"
    exit 1
  }
  case "$cur" in
    *x19) tgt=0x0f who=betazed ;;
    *) tgt=0x19 who=cardassia ;;
  esac
  ${ddcutil}/bin/ddcutil --model "DELL U2724DE" setvcp 60 "$tgt" &&
    ${libnotify}/bin/notify-send -t 3000 "kvm-switch" "monitor → $who"
''
