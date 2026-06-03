{ config, pkgs, lib, ... }:

{
  options = { };

  config = {
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
    # Anti-race override: same as kanshi/blueman/waybar. Sway exec starts
    # kdeconnect in sway's process env where WAYLAND_DISPLAY is set.
    systemd.user.services.kdeconnect.Install.WantedBy = lib.mkForce [ ];
    systemd.user.services.kdeconnect-indicator.Install.WantedBy = lib.mkForce [ ];
  };
}
