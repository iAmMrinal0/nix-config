{ lib, pkgs, config, hostname ? "", ... }:

let
  systemHostName = if hostname != "" then
    hostname
  else if config ? networking.hostName then
    config.networking.hostName
  else
    builtins.getEnv "HOSTNAME";

  hostConfig = if systemHostName != ""
  && builtins.pathExists ./autorandr/${systemHostName}.nix then
    import ./autorandr/${systemHostName}.nix { inherit lib pkgs; }
  else {
    profiles = {
      "default" = {
        fingerprint = { };
        config = { };
      };
    };
  };

in {
  programs.autorandr = {
    enable = true;
    hooks = {
      postswitch = {
        "change-background" =
          lib.readFile (pkgs.callPackage ./common/wallpaper.nix { });
      };
    };
    profiles = hostConfig.profiles;
  };
}
