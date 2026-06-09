{
  description = "NixOS configurations for my machines";

  # Bootstrap caches: cache.nix only applies on an installed system, so a
  # fresh `nixos-install` from the ISO wouldn't know about these. Carrying
  # them in the flake lets the installer use them after the
  # "accept flake config?" prompt (or --accept-flake-config). Only the
  # bootstrap subset — see cache-list.nix for why not the full set.
  # Literals required: the flake parser rejects computed nixConfig values
  # ("setting is a thunk"), so this cannot import cache-list.nix — keep
  # the two in sync by hand.
  nixConfig = {
    extra-substituters = [
      "https://iammrinal0.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "iammrinal0.cachix.org-1:uWCwkRYptDrFnr4qxYyYFJZb4+e/QebcODAe8Of/ngc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-26.05"; };
    nixpkgs-unstable = { url = "github:NixOS/nixpkgs/nixos-unstable"; };
    nur = { url = "github:nix-community/NUR"; };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
    # Declarative Flatpak management: lets us pin remotes and apps in
    # nix and reconcile installed state on rebuild. Used by
    # modules/nixos/gfn.nix to install com.nvidia.geforcenow + its
    # required org.freedesktop.Platform//24.08 runtime. No
    # `nixpkgs.follows` — nix-flatpak doesn't import nixpkgs heavily
    # and pinning it doesn't gain us anything.
    nix-flatpak = { url = "github:gmodena/nix-flatpak/?ref=latest"; };
    emacsConfiguration = {
      url = "github:iammrinal0/.emacs.d";
      # No nixpkgs.follows — the emacs env is prebuilt against .emacs.d's
      # own locked nixpkgs/emacs-overlay and pushed to iammrinal0.cachix.org;
      # following our nixpkgs would change the drv hashes and native-compile
      # everything locally instead of substituting (same reasoning as
      # llm-agents). This also means `nix flake update` here never rebuilds
      # emacs — only bumping this input (after a push of .emacs.d) does.
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
      # Following our nixpkgs would change the drv hashes and miss that cache,
      # native-compiling everything locally; the pin also keeps packages like
      # `apm` on the nixpkgs revision they're actually built and tested against.
    };
    # nixos-06cb-009a-fingerprint-sensor = {
    #   url = "github:ahbnr/nixos-06cb-009a-fingerprint-sensor?ref=25.05";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = inputs@{ self, nixpkgs, nur, home-manager, sops-nix, emacs-overlay
    , nixos-hardware, emacsConfiguration, zsh-autosuggestions, zsh-nix-shell
    , haskell-yesod-quasiquotes, nixpkgs-unstable, nix4vscode, llm-agents
    , nix-index-database, nix-flatpak }:
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
