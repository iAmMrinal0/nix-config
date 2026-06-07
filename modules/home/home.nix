{ config, pkgs, lib, inputs, ... }:

let userPackages = import ../../home/packages.nix { inherit pkgs lib inputs; };
in {
  options = { };

  config = {
    home = {
      packages = userPackages;
      stateVersion = "26.05";
      sessionPath = [
        "$HOME/.local/bin"
        "$HOME/.npm_global/bin"
      ];
      sessionVariables = {
        # gcr-ssh-agent's socket (services.gnome.gcr-ssh-agent, base.nix);
        # the NixOS module doesn't export this itself. $XDG_RUNTIME_DIR is
        # set by pam_systemd before hm-session-vars.sh is sourced.
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/gcr/ssh";
        # Bitwarden's agent still listens here (same path as before, when
        # it was the default agent) — point SSH_AUTH_SOCK at it ad hoc to
        # use vault-held keys.
        BITWARDEN_SSH_AUTH_SOCK = "${config.xdg.dataHome}/ssh-agent";
      };
    };
  };
}
