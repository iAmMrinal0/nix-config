{ config, lib, pkgs, ... }:

{
  # Firefox runs in its own slice with a soft memory ceiling. It is the
  # biggest thing on betazed by far — 7.7G (5G RAM + 2.7G swap) after a day
  # up, half of all swap — and when it fills memory, systemd-oomd reaps
  # whichever cgroup it scores worst, which is often not Firefox: twice in
  # October that was claude-assistant, taking every Remote Control session
  # with it. MemoryHigh= is not a kill line; past it the kernel reclaims
  # Firefox's own pages first (into zram), so the pressure lands on the
  # browser instead of the rest of the desktop.
  #
  # A slice rather than a property on the scope so every launch path — rofi,
  # a terminal, browser-router (xdg/main.nix) — shares the one ceiling, and
  # a link handed to an already-running Firefox doesn't get a budget of its
  # own. app-firefox nests under app.slice by name, next to the scopes
  # rofi.nix creates.
  systemd.user.slices.app-firefox = {
    Unit.Description = "Firefox, with a soft memory ceiling";
    Slice.MemoryHigh = "5G";
  };

  # Every `firefox` on PATH starts in that slice. hiPrio so it wins over the
  # bin/firefox from programs.firefox's own package; the desktop entries say
  # `Exec=firefox`, so they pick it up too.
  #
  # The scope gets an explicit name. Left to itself systemd-run names it
  # run-p<pid>-i<n>.scope, and from rofi — whose run-command is itself an
  # exec'ing systemd-run (rofi.nix) — this script runs under the same PID as
  # rofi's own scope, so the names collide and the launch fails with
  # "already loaded". $SRANDOM is bash's 32-bit random.
  home.packages = lib.mkIf config.programs.firefox.enable [
    (lib.hiPrio (pkgs.writeShellScriptBin "firefox" ''
      exec ${pkgs.systemd}/bin/systemd-run --user --scope --collect --quiet \
        --unit="app-firefox-$SRANDOM" --slice=app-firefox.slice \
        ${config.programs.firefox.finalPackage}/bin/firefox "$@"
    ''))
  ];

  programs.firefox = {
    enable = true;
    # 26.05 moves the firefox profile root from ~/.mozilla/firefox to the
    # XDG path. This option only tells HM/firefox where to look — it does
    # NOT move existing data. The one-time migration must be done manually
    # with firefox closed (see the rebuild note); otherwise firefox starts
    # from an empty profile (old data stays at ~/.mozilla/firefox).
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles = {
      default.settings = {
        "accessibility.typeaheadfind.soundURL" = "";
        "browser.aboutConfig.showWarning" = false;
        "browser.ctrlTab.recentlyUsedOrder" = false;
        "browser.download.panel.shown" = true;
        "browser.newtab.extensionControlled" = true;
        "browser.newtab.privateAllowed" = true;
        "browser.sessionstore.warnOnQuit" = false;
        "browser.warnOnQuit" = false;
        "findbar.highlightAll" = true;
        "privacy.donottrackheader.enabled" = true;
        "signon.autofillForms" = false;
        "signon.importedFromSqlite" = true;
        "signon.rememberSignons" = false;
        "signon.usage.hasEntry" = true;
        "extensions.openPopupWithoutUserGesture.enabled" = true;
        # Unload background tabs when the machine runs low on memory. On by
        # default on Windows and macOS but off on Linux (Firefox 157). Firefox
        # watches system-wide available memory here, not the slice above, and
        # starts unloading below this share of it — 10% is ~1.6G on betazed,
        # comfortably before oomd's 90% swap / 50% pressure lines. Tabs idle
        # for less than min_inactive_duration_before_unload (default 10 min)
        # are left alone.
        "browser.tabs.unloadOnLowMemory" = true;
        "browser.low_commit_space_threshold_percent" = 10;
        # Already the default; pinned so a restored session loads only the
        # tab in front rather than every tab at once.
        "browser.sessionstore.restore_on_demand" = true;
      };
      default.extensions.packages = (with pkgs.nur.repos.rycee.firefox-addons; [
        darkreader
        privacy-badger
        reddit-enhancement-suite
        ublock-origin
        multi-account-containers
        vimium
        octotree
        refined-github
        sponsorblock
        # pkgs.nur.repos.ethancedwards8.firefox-addons.enhancer-for-youtube
      ]);
    };
  };
}
