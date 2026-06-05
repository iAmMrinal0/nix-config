{ config, lib, pkgs, inputs, username, ... }:

with lib;

# Everything required to run NVIDIA GeForce NOW (Flatpak + gamescope
# launcher) in one toggle. Owns:
#   - flatpak service + xdg-desktop-portal (system side)
#   - declarative flatpak remotes + apps via nix-flatpak
#   - the `gfn` launcher script in the user's PATH
#
# After enabling on a fresh host, the first `nixos-rebuild switch`
# downloads ~1.5 GB (the runtime is most of it) and registers the
# remotes. flatpak's activation runs as a oneshot systemd unit so the
# rebuild blocks until installs complete. Subsequent rebuilds are
# fast; nix-flatpak short-circuits when state matches the declaration.

let cfg = config.modules.gfn;
in {
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  options.modules.gfn = {
    enable = mkEnableOption
      "Enable NVIDIA GeForce NOW (Flatpak + gamescope launcher)";
  };

  config = mkIf cfg.enable {
    services.flatpak = {
      enable = true;

      remotes = [
        {
          name = "GeForceNOW";
          location = "https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo";
        }
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      # NVIDIA's GFN client + the freedesktop runtime it depends on.
      # The runtime lives on flathub, not on NVIDIA's own remote, so
      # both remotes are required even though we only use the
      # GeForceNOW remote for the app itself.
      packages = [
        {
          appId = "com.nvidia.geforcenow";
          origin = "GeForceNOW";
        }
        {
          appId = "org.freedesktop.Platform//24.08";
          origin = "flathub";
        }
      ];

      # Don't touch flatpaks installed outside this declaration. Keeps
      # ad-hoc `flatpak install --user something` working without the
      # next rebuild ripping it out.
      uninstallUnmanaged = false;
    };

    # xdg-desktop-portal-gtk covers the Flatpak portal surface (file
    # pickers, opening URIs, etc.).
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      # portal ≥ 1.17 wants an explicit interface → backend mapping instead
      # of "first implementation in lexicographical order" (which is all
      # `enable` alone gives you, plus an eval warning). gtk is the only
      # backend we install, so route everything to it.
      config.common.default = "gtk";
    };

    home-manager.users.${username} = {
      home.packages = [ pkgs.my.scripts.gfn ];
    };
  };
}
