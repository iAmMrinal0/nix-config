{ writeShellScriptBin, ddcutil, libnotify, gawk, gnugrep }:

# Hand the home Dell U2724DE (and its KVM'd peripherals) to the other laptop
# by toggling the monitor's input over DDC/CI: USB-C 0x19 = betazed, DP
# 0x0f = cardassia (as of 2026-07-18; the toggle below doesn't depend on
# which host sits on which input). Run from whichever machine currently has
# the screen. 0x19 is Dell's USB-C code, missing from ddcutil's MCCS table —
# full getvcp prints it as "Invalid value", but the terse form still carries
# the raw value.
#
# The monitor's i2c bus is cached after the first full scan: `--model` walks
# every /dev/i2c-* on each call (10s+ here — the iGPU exposes ~17 buses, and
# any probe failure triggers ddcutil's lsof-based diagnostics dump), while
# `--bus` talks to the monitor directly. If getvcp on the cached bus fails
# (bus numbers move across dock/MST re-enumerations) we re-scan and re-cache.
# The sysfs EDID guard keeps a stale cached bus from ever flipping the input
# of some other DDC monitor (e.g. at the office).
#
# The confirmation is sent *before* setvcp: after it, the screen the user is
# watching belongs to the other machine, so a post-switch notification is
# never seen. --noverify skips the read-back (feature 0x60 doesn't support
# verification on this panel anyway).
writeShellScriptBin "kvm-switch" ''
  notify() { ${libnotify}/bin/notify-send "$@"; }

  ${gnugrep}/bin/grep -aq "DELL U2724DE" /sys/class/drm/card*-*/edid 2>/dev/null || {
    notify -u critical "kvm-switch" "U2724DE not attached (no EDID on any connector)"
    exit 1
  }

  cache=''${XDG_CACHE_HOME:-$HOME/.cache}/kvm-switch-bus
  bus=$(cat "$cache" 2>/dev/null)
  cur=""
  if [ -n "$bus" ]; then
    cur=$(${ddcutil}/bin/ddcutil --bus "$bus" -t getvcp 60 2>/dev/null) || cur=""
  fi
  if [ -z "$cur" ]; then
    bus=$(${ddcutil}/bin/ddcutil detect --brief 2>/dev/null | ${gawk}/bin/awk '
      /I2C bus:/ { sub(".*i2c-", ""); bus = $0 }
      /Monitor:.*DELL U2724DE/ { print bus; exit }')
    if [ -z "$bus" ]; then
      notify -u critical "kvm-switch" "U2724DE not reachable over DDC"
      exit 1
    fi
    echo "$bus" > "$cache"
    cur=$(${ddcutil}/bin/ddcutil --bus "$bus" -t getvcp 60 2>/dev/null) || {
      notify -u critical "kvm-switch" "U2724DE not reachable over DDC (bus $bus)"
      exit 1
    }
  fi

  case "$cur" in
    *x19) tgt=0x0f ;;
    *) tgt=0x19 ;;
  esac
  # Name the host we're leaving, not the guessed destination: $HOSTNAME is
  # ground truth on the machine that currently has the screen, while the
  # input→host mapping silently inverts whenever the cables are swapped.
  notify -t 3000 "kvm-switch" "switching from $HOSTNAME"
  ${ddcutil}/bin/ddcutil --bus "$bus" --noverify setvcp 60 "$tgt" ||
    notify -u critical "kvm-switch" "setvcp failed (bus $bus)"
''
