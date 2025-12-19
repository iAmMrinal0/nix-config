{
  description = "NixOS configurations for my machines";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-25.11"; };
    nixpkgs-unstable = { url = "github:NixOS/nixpkgs/nixos-unstable"; };
    nur = { url = "github:nix-community/NUR"; };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = { url = "github:NixOS/nixos-hardware/master"; };
    emacsConfiguration = {
      url = "github:iammrinal0/.emacs.d";
      flake = false;
    };
    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
      flake = false;
    };
    zsh-you-should-use = {
      url = "github:MichaelAquilina/zsh-you-should-use";
      flake = false;
    };
    zsh-autosuggestions-abbreviations-strategy = {
      url = "github:olets/zsh-autosuggestions-abbreviations-strategy";
      flake = false;
    };
    zsh-nix-shell = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
    };
    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    keepmenu = { url = "github:firecat53/keepmenu"; };
    haskell-yesod-quasiquotes = {
      url = "github:kronor-io/haskell-yesod-quasiquotes";
      flake = false;
    };
    # nixos-06cb-009a-fingerprint-sensor = {
    #   url = "github:ahbnr/nixos-06cb-009a-fingerprint-sensor?ref=25.05";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = inputs@{ self, nixpkgs, nur, home-manager, sops-nix, emacs-overlay
    , nixos-hardware, emacsConfiguration, zsh-autosuggestions
    , zsh-autosuggestions-abbreviations-strategy, zsh-you-should-use
    , zsh-nix-shell, keepmenu, haskell-yesod-quasiquotes, nixpkgs-unstable
    , nix4vscode }: {
      nixosConfigurations = {
        betazed = let hostname = "betazed";
        in nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs hostname; };
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            ./hosts/${hostname}.nix
            ./cache.nix
            sops-nix.nixosModules.sops
            ({ pkgs, inputs, ... }: {
              nixpkgs.overlays = [
                nur.overlays.default
                emacs-overlay.overlay
                nix4vscode.overlays.forVscode
                (import ./overlays)
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    localSystem = pkgs.stdenv.hostPlatform;
                    config = final.config;
                  };
                })
              ];
            })
          ];
        };
        mordor = let hostname = "mordor";
        in nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs hostname; };
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            ./hosts/${hostname}.nix
            ./cache.nix
            sops-nix.nixosModules.sops
            ({ pkgs, inputs, ... }: {
              nixpkgs.overlays = [
                nur.overlays.default
                emacs-overlay.overlay
                nix4vscode.overlays.forVscode
                (import ./overlays)
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    localSystem = pkgs.stdenv.hostPlatform;
                    config = final.config;
                  };
                })
              ];
            })
          ];
        };
      };
    };
}
