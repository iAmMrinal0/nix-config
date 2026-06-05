self: super:
{
  # Namespaced under `my` so callPackage never auto-fills a package's
  # `scripts` argument with this set (bit us with mpv on 26.05).
  my.scripts = import ../pkgs/scripts { pkgs = super; };
  nix-direnv = self.unstable.nix-direnv;

} // (if super ? obsidian then {
  # Only apply the Obsidian wrapper if obsidian package exists
  obsidian = super.obsidian.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/obsidian --add-flags "--enable-unsafe-webgpu --lang=en-gb"
    '';
  });
} else
  { })
