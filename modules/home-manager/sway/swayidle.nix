{ pkgs, ... }:

# Idle daemon for sway. Replaces xss-lock + xautolock + xset DPMS the i3
# setup uses. Behaviour:
#   - 5 min idle    → screen lock (swaylock)
#   - 10 min idle   → outputs powered off (DPMS)
#   - on suspend    → lock first so the lid is locked on resume
#
# We install the binary here and let sway/config.nix exec it directly with
# its full argument list. Earlier attempts to use HM's `services.swayidle`
# (systemd user unit bound to sway-session.target) failed with the same
# WAYLAND_DISPLAY env-import race that bit kanshi/blueman/kdeconnect:
# the unit fired before sway propagated env, swayidle couldn't reach the
# compositor, exited, and never restarted. Manually starting the unit
# from sway exec via `systemctl --user start` was also unreliable.
# Direct exec puts swayidle in sway's process env from the start, no race.
#
# Mordor (i3) doesn't import this — it uses xss-lock + xautolock instead.
{
  home.packages = [ pkgs.swayidle ];
}
