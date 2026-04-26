{ pkgs, config, lib, inputs, ... }:

{
  imports = [
    ../modules/home
    ../modules/home-manager
    ../modules/home/theming.nix
    ../modules/home/host-specific.nix
  ];

  modules.emacs = {
    enable = true;
    package = pkgs.emacs-unstable;
    configureGitWithEmacs = false;
    i3Integration = true;
  };

  personal = {
    theming = {
      enable = true;
      # Colors come from modules/home/theming.nix defaults
      # (Gruvbox Material medium-dark). Override here if per-host.
      font = {
        regular = "Iosevka";
        size = 14;
        package = pkgs.iosevka;
      };
      rofi = { theme = "gruvbox-dark-hard"; };
      kitty = { theme = "GruvboxMaterialDarkMedium"; };
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

