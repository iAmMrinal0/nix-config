{ pkgs, sops-nix, ... }:

pkgs.mkShell {
  sopsPGPKeyDirs = [ "./keys/hosts" "./keys/users" ];
  nativeBuildInputs = [ (pkgs.callPackage sops-nix { }).sops-import-keys-hook ];
}
