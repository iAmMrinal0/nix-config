{ config, pkgs, ... }:

# NOTE: These caches are used on NixOS (nixos-rebuild) only, and not in
# home-manager (which would only use the user's nix.conf).
# The lists live in cache-list.nix, shared with flake.nix's nixConfig
# (which uses only the bootstrap subset).
let caches = import ./cache-list.nix;
in {
  nix.settings.substituters = caches.substituters;
  nix.settings.trusted-public-keys = caches.trusted-public-keys;
}
