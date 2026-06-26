# Wholly-secret user dotfiles, each rendered from sops to a 0600 file in $HOME.
# ~/.aws/config is whole-file (not templated) because its profile/role names
# reveal access too.
{ config, username, ... }:

let
  user = config.users.users.${username};
  dotfile = path: {
    inherit path;
    owner = user.name;
    inherit (user) group;
    mode = "0600";
  };
in {
  # Parent dirs must exist before the rendered files land (fresh-machine-safe).
  systemd.tmpfiles.rules = [
    "d ${user.home}/.aws 0700 ${user.name} ${user.group} -"
    "d ${user.home}/.config/nix 0700 ${user.name} ${user.group} -"
  ];

  sops.secrets = {
    "aws-config" = dotfile "${user.home}/.aws/config";
    "pgpass" = dotfile "${user.home}/.pgpass"; # 0600 or psql ignores it
    "pg-service-conf" = dotfile "${user.home}/.pg_service.conf";
    "netrc" = dotfile "${user.home}/.netrc";
    "nix-netrc" = dotfile "${user.home}/.config/nix/netrc";
  };
}
