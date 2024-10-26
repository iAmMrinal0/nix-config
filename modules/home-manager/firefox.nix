{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
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
      };
      default.extensions = (with pkgs.nur.repos.rycee.firefox-addons; [
        darkreader
        privacy-badger
        reddit-enhancement-suite
        ublock-origin
        multi-account-containers
        keepassxc-browser
        vimium
        octotree
        refined-github
        sponsorblock
        # pkgs.nur.repos.ethancedwards8.firefox-addons.enhancer-for-youtube
      ]);
    };
  };
}
