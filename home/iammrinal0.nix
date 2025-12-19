{ pkgs, config, lib, inputs, ... }:

{
  imports = [
    ../modules/home
    ../modules/home-manager
    ../modules/home/theming.nix
    ../modules/home/host-specific.nix
  ];

  modules.emacs = {
    enable = false;
    package = pkgs.emacs-unstable;
    configureGitWithEmacs = false;
    i3Integration = true;
  };

  personal = {
    theming = {
      enable = true;
      colors = {
        primary = "#ebdbb2"; # Gruvbox foreground
        background = "#1d2021"; # Gruvbox background
        accent = "#fe8019"; # Gruvbox orange
      };
      font = {
        regular = "Iosevka"; # Match the font name from kitty.nix
        size = 16; # Match the font size that was previously in kitty.nix
        package = pkgs.iosevka; # Specify the font package
      };
      rofi = { theme = "gruvbox-dark-hard"; };
      kitty = { theme = "gruvbox-dark-hard"; };
    };

    shell-tools = {
      enable = true;
      atuin.enable = true;
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      fzf.enable = true;
      simpleTools = { enabledTools = [ "broot" "command-not-found" "jq" ]; };
    };

    host-specific = { enable = true; };
  };
}

