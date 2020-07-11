{ config, lib, pkgs, ... }:

{
  # NOTE: These caches are used on NixOS (nixos-rebuild) only, and not in
  # home-manager (which would only use the user's nix.conf).

  nix.binaryCaches = [
    "https://all-hies.cachix.org"
    "https://cachix.cachix.org"
    "https://fencer.cachix.org"
    "https://ghcide-nix.cachix.org/"
    "https://hercules-ci.cachix.org/"
    "https://pre-commit-hooks.cachix.org"
    "https://static-haskell-nix.cachix.org"
    "https://streamly.cachix.org"
  ];
  nix.binaryCachePublicKeys = [
    "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
    "all-hies.cachix.org-1:JjrzAOEUsD9ZMt8fdFbzo3jNAyEWlPAwdVuHw4RD43k="
    "fencer.cachix.org-1:Uc3oXF1AHnhrc7kwEAY+NHNH7BvkngdBiFLHPDCUVwA="
    "ghcide-nix.cachix.org-1:ibAY5FD+XWLzbLr8fxK6n8fL9zZe7jS+gYeyxyWYK5c="
    "hercules-ci.cachix.org-1:ZZeDl9Va+xe9j+KqdzoBZMFJHVQ42Uu/c/1/KMC5Lw0="
    "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
    "static-haskell-nix.cachix.org-1:Q17HawmAwaM1/BfIxaEDKAxwTOyRVhPG5Ji9K3+FvUU="
    "streamly.cachix.org-1:UB4NIzQXJuKsEPAVJH0j9Vy5YsM5Dfx3rc9sHCxsXQY="
  ];
}
