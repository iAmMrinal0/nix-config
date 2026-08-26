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

      # Evolution is here for calendars only (modules/nixos/evolution.nix), so
      # stop it asking to become the default mail client on every start.
      "org/gnome/evolution/mail" = { prompt-check-if-default-mailer = false; };

      # Silence new-mail popups. notify-dbus-enabled is the one that reaches
      # dunst; calendar reminders come from evolution-alarm-notify via
      # org.gnome.evolution-data-server.calendar instead, so they survive this.
      "org/gnome/evolution/plugin/mail-notification" = {
        notify-dbus-enabled = false;
        notify-sound-enabled = false;
      };

      # menubar: 3.60 hides it and gives its toggle no accelerator, stranding
      # Edit -> Accounts, the only route to adding a Google account short of the
      # hamburger. Safe to flip to false once the accounts are in.
      #
      # buttons-style 'toolbar' means "follow the GNOME toolbar setting", which
      # gtk.nix sets to large icons *with* labels for Thunar's sake; 'icons'
      # escapes that here without disturbing the other GTK apps.
      "org/gnome/evolution/shell" = {
        menubar-visible = true;
        buttons-style = "icons";
        prefer-symbolic-icons = "yes";
        toolbar-icon-size = "small";
      };
    };
  };
}
