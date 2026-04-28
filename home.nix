{ inputs, pkgs, lib, config, hostname, username, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.users.${username} = import ./home/${username}.nix;
  home-manager.extraSpecialArgs = { inherit inputs hostname username; };
}
