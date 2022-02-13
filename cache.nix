{ config, pkgs, ... }:

{
  # NOTE: These caches are used on NixOS (nixos-rebuild) only, and not in
  # home-manager (which would only use the user's nix.conf).

  nix.settings.substituters = [
    "https://all-hies.cachix.org"
    "https://cachix.cachix.org"
    "https://fencer.cachix.org"
    "https://ghcide-nix.cachix.org/"
    "https://hercules-ci.cachix.org/"
    "https://hydra.iohk.io"
    "https://mpickering.cachix.org/"
    "https://nix-community.cachix.org"
    "https://nix-linter.cachix.org"
    "https://nixfmt.cachix.org"
    "https://pre-commit-hooks.cachix.org"
    "https://static-haskell-nix.cachix.org"
    "https://streamly.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
    "all-hies.cachix.org-1:JjrzAOEUsD9ZMt8fdFbzo3jNAyEWlPAwdVuHw4RD43k="
    "fencer.cachix.org-1:Uc3oXF1AHnhrc7kwEAY+NHNH7BvkngdBiFLHPDCUVwA="
    "ghcide-nix.cachix.org-1:ibAY5FD+XWLzbLr8fxK6n8fL9zZe7jS+gYeyxyWYK5c="
    "hercules-ci.cachix.org-1:ZZeDl9Va+xe9j+KqdzoBZMFJHVQ42Uu/c/1/KMC5Lw0="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    "mpickering.cachix.org-1:COxPsDJqqrggZgvKG6JeH9baHPue8/pcpYkmcBPUbeg="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "nix-linter.cachix.org-1:BdTne5LEHQfIoJh4RsoVdgvqfObpyHO5L0SCjXFShlE="
    "nixfmt.cachix.org-1:uyEQg16IhCFeDpFV07aL+Dbmh18XHVUqpkk/35WAgJI="
    "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
    "static-haskell-nix.cachix.org-1:Q17HawmAwaM1/BfIxaEDKAxwTOyRVhPG5Ji9K3+FvUU="
    "streamly.cachix.org-1:UB4NIzQXJuKsEPAVJH0j9Vy5YsM5Dfx3rc9sHCxsXQY="
  ];
}
