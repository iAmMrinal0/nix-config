self: super:
{
  # Namespaced under `my` so callPackage never auto-fills a package's
  # `scripts` argument with this set (bit us with mpv on 26.05).
  my.scripts = import ../pkgs/scripts { pkgs = super; };
  nix-direnv = self.unstable.nix-direnv;

} // (if super ? obsidian then {
  # Only apply the Obsidian wrapper if obsidian package exists
  obsidian = super.obsidian.overrideAttrs (oldAttrs: {
    # `--password-store=gnome-libsecret` is what makes Obsidian's encrypted
    # secrets work ("Encryption is not available on this machine" without it).
    # Electron's safeStorage picks its os_crypt backend from
    # base::nix::GetDesktopEnvironment(), which only recognises XDG_CURRENT_DESKTOP
    # values like GNOME/KDE/XFCE. Under sway it's "sway" (and under i3 it's
    # unset), so detection returns OTHER and Chromium silently falls back to the
    # `basic` plaintext store — at which point safeStorage.isEncryptionAvailable()
    # reports false and Obsidian refuses to encrypt. Pinning the backend skips
    # detection entirely. libsecret-0.21.7 is already in electron-unwrapped's
    # RUNPATH, and services.gnome.gnome-keyring (base.nix) provides the
    # org.freedesktop.secrets D-Bus service that backend talks to, so nothing
    # else is needed.
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/obsidian --add-flags "--enable-unsafe-webgpu --lang=en-gb --password-store=gnome-libsecret"
    '';
  });
} else
  { })
