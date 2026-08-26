{ config, lib, ... }:

with lib;

let cfg = config.modules.evolution;
in {
  options.modules.evolution = {
    enable = mkEnableOption "Evolution as the calendar/mail GUI";
  };

  config = mkIf cfg.enable {
    # Also turns on services.gnome.evolution-data-server (the backend that
    # speaks to Google) and gnome-keyring, where the OAuth refresh tokens land.
    # Leaving programs.evolution.plugins empty keeps evolution-ews out: this
    # module overrides the plugin list nixpkgs' evolutionWithPlugins bundles,
    # and there's no Exchange/O365 here. Accounts are added in-app, through
    # Evolution's own Google consent flow.
    programs.evolution.enable = true;

    # Nothing else here turns dconf on. Reads would still work, but writes need
    # ca.desrt.dconf on the session bus, so without this every Evolution
    # preference is silently dropped on exit.
    programs.dconf.enable = true;

    # Reminders come from evolution-alarm-notify, a separate daemon. EDS ships
    # its unit and systemd.packages installs it, but systemd reads [Install]
    # only at enable time and nothing here runs `systemctl --user enable` — so
    # without the wants below, calendars sync and simply never notify.
    #
    # overrideStrategy defaults to asDropinIfExists, so this extends the shipped
    # unit rather than replacing it: that unit is Type=dbus with a BusName, and
    # redeclaring ExecStart here would leave it with two.
    systemd.user.services.evolution-alarm-notify = {
      # Upstream's own choice, and it reaches both session picks:
      # sway-session.target BindsTo it, and under i3 the X session wrapper
      # starts nixos-fake-graphical-session.target, which does too.
      #
      # A new .wants symlink can't reach into an already-active target, so log
      # out and in (or start it by hand) the first time.
      wantedBy = [ "graphical-session.target" ];

      # At logout graphical-session.target stays active, so alarm-notify keeps
      # running against a dead display, where the aborting gtk_init() exits it
      # nonzero. Upstream's Restart=on-failure plus the default 5-in-10s burst
      # would park it in `failed` for good, and a .wants symlink can't retrigger
      # it (the wedge in modules/home-manager/blueman-applet.nix). Drop the
      # limit so it recovers at the next login; back off so idling at the
      # greeter doesn't fill the journal.
      startLimitIntervalSec = 0;
      serviceConfig.RestartSec = 30;

      # Left at its default this injects NixOS' minimal Environment=PATH=,
      # overriding the session PATH the daemon would inherit; upstream sets none.
      enableDefaultPath = false;
    };
  };
}
