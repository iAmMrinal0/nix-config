# Stamp every generation with the nix-config git short rev + commit date, so
# the systemd-boot menu and store path identify which commit a generation came
# from (dirty trees become "dirty"+short rev). Standalone and unconditional so
# both the desktop hosts (via modules/nixos) and lean hosts that import this
# file directly (e.g. yggdrasil, which skips base.nix) share one label format.
# Pair with `modules.systemLabel.suffix` for named recovery checkpoints.
{ config, lib, inputs, ... }:

with lib;

let
  cfg = config.modules.systemLabel;
  flakeRev = inputs.self.shortRev or inputs.self.dirtyShortRev or "dirty";
  flakeDate = inputs.self.lastModifiedDate or "unknown";
in {
  options.modules.systemLabel.suffix = mkOption {
    type = types.str;
    default = "";
    example = "stable-pre-upgrade";
    description = ''
      Optional suffix appended to the systemd-boot generation label, after the
      git commit and timestamp. Set it before a known-good build (e.g.
      "stable-pre-upgrade") so the generation is easy to find in the boot menu.
    '';
  };

  config.system.nixos.label = mkForce (
    flakeRev + "-" + flakeDate
    + optionalString (cfg.suffix != "") ("-" + cfg.suffix)
  );
}
