{ pkgs, config, lib, inputs, ... }:
let userPackages = import ./packages.nix { inherit pkgs lib inputs; };
in {
  xdg = {
    enable = true;
    configFile."pgcli/config".text = builtins.readFile ../config/pgcli;
  };

  dconf.settings."gnome/desktop/sound" = { event-sounds = false; };

  services = {
    gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
    };
    kdeconnect = {
      enable = true;
      indicator = true;
    };
    playerctld.enable = true;
    udiskie.enable = true;
  };

  programs = {
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
    broot.enable = true;
    command-not-found.enable = true;
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    gpg.enable = true;
    home-manager.enable = true;
    jq.enable = true;
  };

  home = {
    packages = userPackages;
    stateVersion = "24.05";
    sessionVariables = {
      SSH_AUTH_SOCK = "${config.xdg.dataHome}/ssh-agent";
      BITWARDEN_SSH_AUTH_SOCK = "${config.home.sessionVariables.SSH_AUTH_SOCK}";
    };
  };

  imports = [ ../modules/home-manager ];
}

