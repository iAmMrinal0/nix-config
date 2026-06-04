{ config, pkgs, ... }:

{
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
