{ writeShellScriptBin, pulseaudio }:

# Toggle the default source's mute AND mirror the result to the ThinkPad
# mic-mute LED. The bare `pactl set-source-mute` the keybinds used before is a
# PipeWire *software* mute, which never touches the hardware capture control the
# kernel `audio-micmute` LED trigger watches — so the mic muted but the F4 light
# never came on. We drive the LED sysfs node directly (made group-writable for
# `audio` by a udev rule in base.nix). The LED follows @DEFAULT_SOURCE@, so it
# tracks whatever the current default mic is (laptop Mic1 normally, the XM3 if
# you've made it default). No-op on hosts without the LED (the `-w` guard).
writeShellScriptBin "mic-mute-toggle" ''
  led=/sys/class/leds/platform::micmute/brightness
  ${pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle
  if [ -w "$led" ]; then
    if ${pulseaudio}/bin/pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes; then
      echo 1 > "$led"
    else
      echo 0 > "$led"
    fi
  fi
''
