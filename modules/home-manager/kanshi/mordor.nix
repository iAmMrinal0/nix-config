{ lib, pkgs, ... }:

# Profiles for mordor (T14s). Phase 1 placeholder — only the laptop-alone
# profile is wired up. The home-right / bzt-dual / bzt-dual-alt profiles port
# in Phase 3 once mordor is being migrated; the autorandr profiles in
# modules/home-manager/autorandr/mordor.nix remain authoritative until then.
#
# To finalize: boot sway once on mordor, run `swaymsg -t get_outputs` with each
# monitor combination plugged in, capture the identifiers, and translate the
# autorandr profiles below into kanshi format mirroring kanshi/betazed.nix.
let
  t14s = {
    status = "enable";
    mode = "2560x1440@59.96Hz";
    position = "0,0";
  };
in {
  profiles = {
    default = {
      outputs = [
        ({ criteria = "eDP-1"; } // t14s)
      ];
    };
  };
}
