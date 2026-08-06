{ inputs, pkgs, lib, config, hostname, username, role, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.sharedModules = [ inputs.nix-index-database.homeModules.nix-index ]
    # The namespaced VPN units (kronor.nix) only exist on work hosts.
    ++ lib.optional (role == "work") ./kronor-home.nix;
  home-manager.users.${username} = import ./home/${username}.nix;
  home-manager.extraSpecialArgs = { inherit inputs hostname username role; };
}
