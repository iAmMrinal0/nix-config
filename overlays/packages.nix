self: super:
{
  scripts = import ../pkgs/scripts { pkgs = super; };

} // (if super ? obsidian then {
  # Only apply the Obsidian wrapper if obsidian package exists
  obsidian = super.obsidian.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/obsidian --add-flags "--enable-unsafe-webgpu --lang=en-gb"
    '';
  });
} else
  { })
