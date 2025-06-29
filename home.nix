{ inputs, pkgs, lib, config, hostname, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.users.iammrinal0 = import ./home/iammrinal0.nix;
  home-manager.extraSpecialArgs = { inherit inputs hostname; };
}
