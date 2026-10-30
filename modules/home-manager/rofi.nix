{ pkgs, ... }: {
  programs.rofi = {
    enable = true;

    # lines = 5;
    # padding = 1;
    # width = 30;
    # borderWidth = 1;
    # separator = "none";
    # rowHeight = 2;
    # extraConfig = { };
    # scrollbar = false;
    # terminal = "${pkgs.kitty}/bin/kitty";
    # font = "Iosevka 25";
    plugins = [ pkgs.rofi-calc ];
    # Theme is now managed by the theming module
    # theme = "gruvbox-dark-hard";
    extraConfig = {
      # hide-scrollbar = true;
      # separator = "none";
      matching = "fuzzy";
      # Launch every run/drun pick in its own transient scope under
      # app.slice. Otherwise the app inherits the WM's cgroup, which is the
      # logind session-N.scope — so Firefox/VS Code piled up inside the
      # compositor's scope. When swap filled, oomd skipped the app scopes
      # (each under its ~5%-of-swap floor) and, despite
      # ManagedOOMPreference=avoid (memory-safeguards.nix), killed the
      # session scope holding 7.8G of swap — sway and every window with it
      # (betazed, 2026-10-04). In its own scope the browser is a normal
      # candidate and gets reaped instead of the whole desktop.
      run-command = "${pkgs.systemd}/bin/systemd-run --user --scope --collect --quiet --slice=app.slice {cmd}";
      # padding = 1;
      # rowHeight = 2;
      # borderWidth = 1;
      # lines = 5;
      # width = 30;
    };
  };
}
