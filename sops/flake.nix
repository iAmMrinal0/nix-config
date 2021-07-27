{
  description = "sops-nix development shell";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, sops-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in { devShell = import ./shell.nix { inherit pkgs sops-nix; }; });
}
