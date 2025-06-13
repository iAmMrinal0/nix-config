{ lib, inputs, config, pkgs, ... }: {
  home-manager = {
    backupFileExtension = "hm-backup";
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs; osConfig = config; };
    users.iammrinal0 = import ./home/iammrinal0.nix;
  };
}
