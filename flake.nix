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
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacsConfiguration = {
      url = "github:iammrinal0/.emacs.d";
      flake = false;
    };
    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
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
    haskell-yesod-quasiquotes = {
      url = "github:kronor-io/haskell-yesod-quasiquotes";
      flake = false;
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      # Intentionally not following our nixpkgs — numtide pre-builds against
      # its own pinned nixpkgs and pushes those exact paths to cache.numtide.com.
      # Following our nixpkgs would (a) miss the cache and (b) break packages
      # like `apm` that use newer-than-25.11 nixpkgs APIs.
    };
    # nixos-06cb-009a-fingerprint-sensor = {
    #   url = "github:ahbnr/nixos-06cb-009a-fingerprint-sensor?ref=25.05";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = inputs@{ self, nixpkgs, nur, home-manager, sops-nix, emacs-overlay
    , nixos-hardware, emacsConfiguration, zsh-autosuggestions, zsh-nix-shell
    , haskell-yesod-quasiquotes, nixpkgs-unstable, nix4vscode, llm-agents
    , nix-index-database }:
    let username = "iammrinal0";
    in {
      nixosConfigurations = {
        betazed = let hostname = "betazed";
        in nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs hostname username; };
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
          specialArgs = { inherit inputs hostname username; };
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
