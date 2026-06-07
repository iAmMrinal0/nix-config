{ osConfig, ... }:
let
  # System-level sops-nix secrets (decrypted to /run/secrets, made
  # user-readable via the defaultPermissions helper in base.nix).
  sopsSecrets = osConfig.sops.secrets;
in {
  # Declarative rclone config. The HM module renders a real, writable
  # ~/.config/rclone/rclone.conf at login (rclone-config.service): it
  # generates the non-secret fields from `config` and injects the secret
  # fields by cat-ing the sops secret paths, publishing atomically. The
  # file stays writable so rclone can persist refreshed OAuth access
  # tokens between rebuilds; a rebuild re-seeds it from sops (harmless —
  # the durable refresh_token in the sops `token` blob doesn't change,
  # rclone just re-mints an access token). Nothing sensitive enters the
  # nix store. The mount units (systemd.nix) order After this service.
  programs.rclone = {
    enable = true;
    remotes = {
      gdrive = {
        config = {
          type = "drive";
          scope = "drive";
        };
        secrets = {
          client_id = sopsSecrets."rclone-gdrive-client-id".path;
          client_secret = sopsSecrets."rclone-gdrive-client-secret".path;
          token = sopsSecrets."rclone-gdrive-token".path;
        };
      };
      # WebDAV over the tailnet — no credentials, fully declarable.
      tdrive = {
        config = {
          type = "webdav";
          url = "http://100.100.100.100:8080";
          vendor = "other";
        };
      };
    };
  };
}
