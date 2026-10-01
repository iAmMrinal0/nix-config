{ writeShellScriptBin, pulseaudio, playerctl, curl, coreutils, gnused
, procps, gawk }:

# Posts this machine's state to an HTTP endpoint. Unit and credentials:
# modules/home/services/mbient.nix.
#
# Polls rather than using `pactl subscribe`: the debounce below dominates
# latency anyway, so a second long-lived process would buy nothing.

writeShellScriptBin "mbient-report" ''
  set -u

  : "''${MBIENT_URL_FILE:?MBIENT_URL_FILE must point at the base URL}"
  : "''${MBIENT_TOKEN_FILE:?MBIENT_TOKEN_FILE must point at the bearer token}"
  HOST="''${MBIENT_HOST:-$(${coreutils}/bin/hostname)}"

  URL=$(${coreutils}/bin/cat "$MBIENT_URL_FILE")
  TOKEN=$(${coreutils}/bin/cat "$MBIENT_TOKEN_FILE")

  POLL=2
  HEARTBEAT=30

  # Debounce, in polls. Only a call opens a mic stream, so that asserts fast.
  # Playback also opens for notification pings, so it needs much longer.
  # Streams vanish instantly on leave, but a headphone swap reopens them.
  MIC_ASSERT=2    # ~4s
  PLAY_ASSERT=10  # ~20s
  CLEAR=4         # ~8s

  mic_streak=0
  play_streak=0
  gone_streak=0
  on_call=false
  last_payload=""
  last_sent=0

  # Match the process binary: the WebRTC layer names the stream, so
  # application.name is "WEBRTC VoiceEngine". Loose match survives the
  # nixpkgs wrapper (".Discord-wrapped").
  #
  # Browser calls (Meet) show up as "Google Chrome input" from binary
  # "chrome". Only a browser's mic counts, and only while uncorked: its
  # playback is every video tab, which says nothing about a call.
  call_streams() {
    ${pulseaudio}/bin/pactl list "$1" 2>/dev/null \
      | ${coreutils}/bin/tr '[:upper:]' '[:lower:]' \
      | ${gawk}/bin/awk -v browsers="$2" '
          function flush() {
            if (bin ~ /discord/ || (browsers && !corked && bin ~ /"(chrome|chromium|brave|\.?firefox(-wrapped)?)"/)) n++
          }
          /^(source output|sink input) #/ { if (seen) flush(); seen = 1; bin = ""; corked = 0 }
          /^\tcorked: yes/ { corked = 1 }
          /application\.process\.binary = / { bin = $0 }
          END { if (seen) flush(); print n + 0 }'
  }

  json_escape() {
    ${coreutils}/bin/printf '%s' "$1" \
      | ${gnused}/bin/sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g'
  }

  while :; do
    mic=$(call_streams source-outputs 1)
    play=$(call_streams sink-inputs 0)

    if [ "$mic" -gt 0 ]; then mic_streak=$((mic_streak + 1)); else mic_streak=0; fi
    if [ "$play" -gt 0 ]; then play_streak=$((play_streak + 1)); else play_streak=0; fi
    if [ "$mic" -eq 0 ] && [ "$play" -eq 0 ]; then
      gone_streak=$((gone_streak + 1))
    else
      gone_streak=0
    fi

    if [ "$mic_streak" -ge "$MIC_ASSERT" ] || [ "$play_streak" -ge "$PLAY_ASSERT" ]; then
      on_call=true
    elif [ "$gone_streak" -ge "$CLEAR" ]; then
      on_call=false
    fi

    # Match comm, not cmdline: the wrapper makes comm ".swaylock-wrapp" (15
    # chars), and -f would match swayidle's cmdline permanently. Never
    # flock-test swaylock-custom.lock - winning it would make a real lock
    # trigger hit its single-instance guard and skip locking.
    if ${procps}/bin/pgrep -x '\.?swaylock(-wrapp)?' >/dev/null 2>&1; then
      presence=locked
    else
      presence=active
    fi

    music=null
    if [ "$(${playerctl}/bin/playerctl --player=spotify status 2>/dev/null)" = "Playing" ]; then
      title=$(${playerctl}/bin/playerctl --player=spotify metadata title 2>/dev/null)
      artist=$(${playerctl}/bin/playerctl --player=spotify metadata artist 2>/dev/null)
      if [ -n "$title" ]; then
        music="{\"title\":\"$(json_escape "$title")\",\"artist\":\"$(json_escape "$artist")\"}"
      fi
    fi

    payload="{\"host\":\"$HOST\",\"call\":$on_call,\"presence\":\"$presence\",\"music\":$music}"
    now=$(${coreutils}/bin/date +%s)

    # On change, else once per heartbeat: silence is read as absent.
    if [ "$payload" != "$last_payload" ] || [ $((now - last_sent)) -ge "$HEARTBEAT" ]; then
      if ${curl}/bin/curl -sS -m 8 -o /dev/null \
           -X POST "$URL/report" \
           -H "authorization: Bearer $TOKEN" \
           -H "content-type: application/json" \
           -d "$payload"; then
        last_payload="$payload"
        last_sent="$now"
      fi
      # Failure leaves last_payload alone so the next poll retries.
    fi

    ${coreutils}/bin/sleep "$POLL"
  done
''
