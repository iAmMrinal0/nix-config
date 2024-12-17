{
  description = "NixOS configurations for my machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nur.url = "github:nix-community/NUR";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
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
    haskell-yesod-quasiquotes.url = "github:kronor-io/haskell-yesod-quasiquotes";
    haskell-yesod-quasiquotes.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, nur, home-manager, sops-nix, emacs-overlay
    , nixos-hardware, emacsConfiguration, nix-vscode-extensions
    , zsh-autosuggestions, zsh-you-should-use, zsh-history-substring-search
    , zsh-nix-shell, keepmenu, haskell-yesod-quasiquotes }: {
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
          { nixpkgs.overlays = [ nur.overlay emacs-overlay.overlay nix-vscode-extensions.overlays.default ]; }
        ];
        specialArgs = {
          inherit zsh-autosuggestions zsh-you-should-use
            zsh-history-substring-search zsh-nix-shell;
        };
      };
      nixosConfigurations.mordor = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./cache.nix
          ./hardware/mordor.nix
          ./hosts/mordor.nix
          ./nix-config.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          nixos-hardware.nixosModules.lenovo-thinkpad-t14s
          {
            nixpkgs.overlays = [
              nur.overlays.default
              emacs-overlay.overlay
              nix-vscode-extensions.overlays.default
            ];
          }
        ];
        specialArgs = { inherit inputs; };
      };
    };
}
