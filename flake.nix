{
  description = "NixOS configurations for my machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nur, home-manager, sops-nix, emacs-overlay
    , nixos-hardware }: {
      nix.registry.nixpkgs.flake = nixpkgs;
      nixosConfigurations.betazed = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./cache.nix
          ./hardware/betazed.nix
          ./hosts/betazed.nix
          ./base.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          nixos-hardware.nixosModules.lenovo-thinkpad-t480
          { nixpkgs.overlays = [ nur.overlay emacs-overlay.overlay ]; }
        ];
      };
    };
}
