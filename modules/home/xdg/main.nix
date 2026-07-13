{ config, osConfig, pkgs, ... }:

let
  # The "default browser" is a dispatcher, not a real browser: it routes by
  # URL. Work domains open in Chrome under a specific account; everything
  # else opens in Firefox.
  #   boozt           -> the boozt.com Workspace account
  #   datadog, kronor -> the kronor.io Workspace account
  # The Chrome profile is resolved by account at runtime: --profile-directory
  # wants the on-disk dir name ("Profile 5"), but those names are assigned by
  # Chrome in account-creation order and live in machine-local Local State,
  # not in this config — so hardcoding them breaks when set up on a new
  # machine. We match on hosted_domain (the Workspace domain) rather than the
  # full email address, both to keep personal addresses out of this public
  # repo and because the domain is already implied by the URL match below. If
  # the account isn't signed in yet we fall back to Chrome's default profile
  # rather than spawning a phantom one.
  #
  # Registered as browser-router.desktop and wired as every http(s)/html
  # handler below. Referencing the wrapped firefox (finalPackage) keeps the
  # HM profile + extensions; Chrome comes from the google-chrome package.
  # Routing keys off the first arg only (xdg-open and app links pass a single
  # URL); a bare launch falls through to the fallback browser.
  #
  # Non-work URLs go to Firefox, but only when it's enabled. If a host
  # disables programs.firefox, finalPackage is null and interpolating it
  # would break evaluation — so the fallback is computed at eval time and
  # degrades to Chrome's default profile when Firefox is absent (this branch
  # never forces finalPackage).
  fallbackExec = if config.programs.firefox.enable then
    ''exec "${config.programs.firefox.finalPackage}/bin/firefox" "$@"''
  else
    ''exec "$chrome" "$@"'';
  browser-router = pkgs.writeShellScriptBin "browser-router" ''
    chrome=${pkgs.google-chrome}/bin/google-chrome-stable
    jq=${pkgs.jq}/bin/jq
    state="$HOME/.config/google-chrome/Local State"

    # Echo the profile dir for the account on Workspace domain $1, else nothing.
    profile_for() {
      [ -r "$state" ] || return 0
      "$jq" -r --arg domain "$1" '
        (.profile.info_cache // {}) | to_entries[]
        | select(.value.hosted_domain == $domain) | .key' "$state" 2>/dev/null \
        | head -1
    }

    case "$1" in
      *boozt*)            dir=$(profile_for "boozt.com") ;;
      *datadog*|*kronor*) dir=$(profile_for "kronor.io") ;;
      *)                  ${fallbackExec} ;;
    esac

    if [ -n "$dir" ]; then
      exec "$chrome" --profile-directory="$dir" "$@"
    else
      exec "$chrome" "$@"
    fi
  '';
in {
  options = { };

  config = {
    home.packages = [ browser-router ];

    xdg.desktopEntries.browser-router = {
      name = "Browser Router";
      genericName = "Web Browser";
      exec = "${browser-router}/bin/browser-router %U";
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "text/html"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };

    xdg = {
      enable = true;
      # Declarative user dirs: user-dirs.dirs becomes HM-managed instead of
      # mutable state written by xdg-user-dirs-update, and the dirs are
      # created on activation — a fresh $HOME comes up deterministic.
      # Templates/Public are nulled (never used); they won't be created on
      # new machines, existing empty ones can be rmdir'd.
      userDirs = {
        enable = true;
        createDirectories = true;
        # Adopt the 26.05 default (stateVersion 24.05 would otherwise warn
        # and keep the legacy `true`): don't export XDG_DOWNLOAD_DIR & co.
        # as session variables — nothing in this config reads them (verified
        # by grep), apps get the dirs from user-dirs.dirs directly.
        setSessionVariables = false;
        desktop = "${config.home.homeDirectory}/Desktop";
        documents = "${config.home.homeDirectory}/Documents";
        download = "${config.home.homeDirectory}/Downloads";
        music = "${config.home.homeDirectory}/Music";
        pictures = "${config.home.homeDirectory}/Pictures";
        videos = "${config.home.homeDirectory}/Videos";
        templates = null;
        publicShare = null;
      };
      # pgcli configs are rendered at system activation by sops-nix
      # (modules/nixos/pgcli.nix): benign base from config/pgcli plus the
      # secret [alias_dsn] sections appended, per-environment variants
      # included. Symlinked out of store so the DSNs never enter /nix/store.
      configFile."pgcli/config".source = config.lib.file.mkOutOfStoreSymlink
        osConfig.sops.templates."pgcli-config".path;
      configFile."pgcli/pgcli-prod".source = config.lib.file.mkOutOfStoreSymlink
        osConfig.sops.templates."pgcli-prod".path;
      configFile."pgcli/pgcli-staging".source =
        config.lib.file.mkOutOfStoreSymlink
        osConfig.sops.templates."pgcli-staging".path;

      # Default application associations (mimeapps.list). Apps occasionally
      # rewrite this file at runtime ("Set as default" / xdg-mime), which
      # would turn the HM symlink back into a regular file and abort the next
      # activation on the backup conflict — so force-overwrite, same as
      # gtk-3.0/bookmarks. The magnet handler points at the canonical
      # transmission-gtk.desktop rather than the runtime-generated
      # userapp-transmission-gtk-*.desktop alias that was in the mutable file.
      configFile."mimeapps.list".force = true;
      mimeApps = {
        enable = true;
        defaultApplications = {
          "x-scheme-handler/http" = "browser-router.desktop";
          "x-scheme-handler/https" = "browser-router.desktop";
          "x-scheme-handler/chrome" = "browser-router.desktop";
          "text/html" = "browser-router.desktop";
          "application/xhtml+xml" = "browser-router.desktop";
          "application/x-extension-htm" = "browser-router.desktop";
          "application/x-extension-html" = "browser-router.desktop";
          "application/x-extension-shtml" = "browser-router.desktop";
          "application/x-extension-xhtml" = "browser-router.desktop";
          "application/x-extension-xht" = "browser-router.desktop";
          "x-scheme-handler/magnet" = "transmission-gtk.desktop";
          "image/png" = "feh.desktop";
          "image/jpeg" = "feh.desktop";
          "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
          "application/zip" = "xarchiver.desktop";
          "text/plain" = "code.desktop";
          "application/x-zerosize" = "code.desktop";
        };
      };
    };
  };
}
