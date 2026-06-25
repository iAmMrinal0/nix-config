{ config, pkgs, lib, ... }:

with lib;

let cfg = config.personal.dconf;
in {
  options.personal.dconf = {
    enable = mkEnableOption "dconf settings";

    sound = {
      eventSounds = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable GNOME event sounds";
      };
    };

    appearance = {
      preferDarkTheme = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to prefer dark theme for applications";
      };
    };
  };

  config = mkIf cfg.enable {
    dconf.settings = {
      "gnome/desktop/sound" = { event-sounds = cfg.sound.eventSounds; };

      "org/gnome/desktop/interface" =
        mkIf cfg.appearance.preferDarkTheme { color-scheme = "prefer-dark"; };

      # Nautilus (GNOME Files) preferences. click-policy = "single" is the
      # Nautilus equivalent of Thunar's misc-single-click; the rest mirror the
      # tweaks set on betazed (offer "Create Link" / "Delete Permanently" in
      # the context menu, default to icon view).
      "org/gnome/nautilus/preferences" = {
        click-policy = "single";
        show-create-link = true;
        show-delete-permanently = true;
        default-folder-viewer = "icon-view";
      };
    };
  };
}
