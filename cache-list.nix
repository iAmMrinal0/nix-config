# Plain data, no module arguments: the full cache set applied by cache.nix
# on installed systems. flake.nix's nixConfig carries the bootstrap subset
# below as LITERALS (the flake parser rejects computed nixConfig values),
# so changes to `bootstrap` must be mirrored there by hand.
rec {
  substituters = [
    "https://cachix.cachix.org"
    "https://hercules-ci.cachix.org/"
    "https://nix-community.cachix.org"
    "https://pre-commit-hooks.cachix.org"
    "https://iammrinal0.cachix.org"
    "https://cache.numtide.com"
  ];

  trusted-public-keys = [
    "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
    "hercules-ci.cachix.org-1:ZZeDl9Va+xe9j+KqdzoBZMFJHVQ42Uu/c/1/KMC5Lw0="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
    "iammrinal0.cachix.org-1:uWCwkRYptDrFnr4qxYyYFJZb4+e/QebcODAe8Of/ngc="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  # Only the caches that actually hold system-closure artifacts:
  # iammrinal0 (own pushes) and nix-community (e.g. prebuilt
  # emacs-overlay). The rest above are project/dev-shell caches — extra
  # substituters slow down every cache-miss query during an install and
  # widen the binary trust surface, so the bootstrap set stays minimal.
  bootstrap = {
    substituters = [
      "https://iammrinal0.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "iammrinal0.cachix.org-1:uWCwkRYptDrFnr4qxYyYFJZb4+e/QebcODAe8Of/ngc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
