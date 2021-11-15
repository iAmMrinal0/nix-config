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
  };

  outputs = { self, nixpkgs, nur, home-manager, sops-nix, emacs-overlay
    , nixos-hardware, emacsConfiguration, zsh-autosuggestions
    , zsh-you-should-use, zsh-history-substring-search, zsh-nix-shell }: {
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
        specialArgs = {
          inherit emacsConfiguration zsh-autosuggestions zsh-you-should-use
            zsh-history-substring-search zsh-nix-shell;
        };
      };
      homeConfigurations = {
        wsl = home-manager.lib.homeManagerConfiguration {
          configuration = { pkgs, lib, ... }: {
            imports = [ ./home.nix ];
            nixpkgs = {
              config = {
                allowUnfree = true;
                permittedInsecurePackages = [ "electron-9.4.4" ];
              };
            };
          };
          system = "x86_64-linux";
          homeDirectory = "/home/iammrinal0";
          username = "iammrinal0";
          extraSpecialArgs = {
            inherit emacsConfiguration zsh-autosuggestions zsh-you-should-use
              zsh-history-substring-search zsh-nix-shell;
          };
        };
      };
      wsl = self.homeConfigurations.wsl.activationPackage;
      defaultPackage.x86_64-linux = self.wsl;
    };
}
