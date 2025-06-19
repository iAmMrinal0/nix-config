{ config, pkgs, lib, ... }:

{
  imports = [
    # Security-related services
    ./services/gpg-agent.nix
    
    # System services group
    ./services/system-services.nix
    
  ];
  
  personal = {
    gpg-agent = {
      enable = true;
      pinentryFlavor = "qt";
      defaultCacheTtl = 3600;  # 1 hour
      maxCacheTtl = 86400;     # 24 hours
      enableSshSupport = false;
    };
  };
}
