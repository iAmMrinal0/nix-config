{
  description = "NixOS configurations for my machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    emacsConfiguration.url = "github:iammrinal0/.emacs.d";
    emacsConfiguration.flake = false;
    zsh-autosuggestions.url = "github:zsh-users/zsh-autosuggestions";
    zsh-autosuggestions.flake = false;
    zsh-you-should-use.url = "github:MichaelAquilina/zsh-you-should-use";
    zsh-you-should-use.flake = false;
    zsh-history-substring-search.url =
      "github:zsh-users/zsh-history-substring-search";
    zsh-history-substring-search.flake = false;
    zsh-nix-shell.url = "github:chisui/zsh-nix-shell";
    zsh-nix-shell.flake = false;
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    keepmenu.url = "github:firecat53/keepmenu";
    haskell-yesod-quasiquotes.url =
      "github:kronor-io/haskell-yesod-quasiquotes";
    haskell-yesod-quasiquotes.flake = false;
    zsh-autosuggestions-abbreviations-strategy = {
      url = "github:olets/zsh-autosuggestions-abbreviations-strategy";
      flake = false;
    };
    # nixos-06cb-009a-fingerprint-sensor = {
    #   url = "github:ahbnr/nixos-06cb-009a-fingerprint-sensor?ref=25.05";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = inputs@{ self, nixpkgs, nur, home-manager, sops-nix, emacs-overlay
    , nixos-hardware, emacsConfiguration, nix-vscode-extensions
    , zsh-autosuggestions, zsh-autosuggestions-abbreviations-strategy
    , zsh-you-should-use, zsh-history-substring-search, zsh-nix-shell, keepmenu
    , haskell-yesod-quasiquotes, nixpkgs-unstable }: {
      nixosConfigurations = {
        betazed = let hostname = "betazed";
        in nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs hostname; };
          modules = [
            ./hosts/${hostname}.nix
            ./cache.nix
            sops-nix.nixosModules.sops
            {
              nixpkgs.overlays = [
                nur.overlays.default
                emacs-overlay.overlay
                nix-vscode-extensions.overlays.default
                (import ./overlays)
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    system = final.system;
                    config = final.config;
                  };
                })
              ];
            }
          ];
        };
        mordor = let hostname = "mordor";
        in nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs hostname; };
          modules = [
            ./hosts/${hostname}.nix
            ./cache.nix
            sops-nix.nixosModules.sops
            {
              nixpkgs.overlays = [
                nur.overlays.default
                emacs-overlay.overlay
                nix-vscode-extensions.overlays.default
                (import ./overlays)
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    system = final.system;
                    config = final.config;
                  };
                })
              ];
            }
          ];
        };
      };
    };
}
