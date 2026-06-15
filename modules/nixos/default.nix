{ lib, hostname, ... }:

{
  imports = [
    ./adb.nix
    ./audio.nix
    ./bluetooth.nix
    ./boot.nix
    ./connectiq.nix
    ./display-manager.nix
    ./docker.nix
    ./emacs.nix
    ./fonts.nix
    ./gc.nix
    ./gfn.nix
    ./memory-safeguards.nix
    ./networking.nix
    ./nfs.nix
    ./openrazer.nix
    ./pgcli.nix
    ./printing.nix
    ./tailscale.nix
    ./touchegg.nix
    ./vscode.nix
    ./xserver.nix
    ./wayland-session.nix
  ]
  # disk-layout.nix defines config under the `disko` option, which is provided
  # only on cardassia (its flake output imports disko.nixosModules.disko).
  # Import it only there so betazed/mordor don't fail on the undeclared option.
  ++ lib.optional (hostname == "cardassia") ./disk-layout.nix;
}
