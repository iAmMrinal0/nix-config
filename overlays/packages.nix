self: super:
let
  # grim shim for flameshot. Flameshot's overlay covers ONE output on
  # Wayland — its whole-desktop move/resize + BypassWindowManagerHint trick
  # in CaptureWidget is X11-only, and Qt refuses to size a toplevel past one
  # screen — so the stock full-desktop grim capture renders cut off. Capture
  # only the focused output instead and the fullscreen overlay matches it
  # 1:1. The Print binding (modules/home-manager/sway/config.nix) pins the
  # overlay to that same output. Assumes output scale 1.0: grim captures at
  # buffer resolution, so any non-1.0 scale (integer or fractional) would
  # misalign. Side effect: `flameshot screen`/`full` now mean "focused
  # output" (and `screen`'s global-geometry crop would misfire) — only
  # `gui` is bound anywhere.
  grimFocusedOutput = super.writeShellScriptBin "grim" ''
    real=${super.grim}/bin/grim
    # explicit output/geometry requests pass through untouched
    case " $* " in
      *" -o "* | *" -g "*) exec "$real" "$@" ;;
    esac
    out=$(${super.sway}/bin/swaymsg -t get_outputs --raw 2>/dev/null \
      | ${super.jq}/bin/jq -r '.[] | select(.focused).name' 2>/dev/null)
    if [ -n "$out" ]; then
      exec "$real" -o "$out" "$@"
    fi
    exec "$real" "$@"
  '';
in
{
  # Namespaced under `my` so callPackage never auto-fills a package's
  # `scripts` argument with this set (bit us with mpv on 26.05).
  my.scripts = import ../pkgs/scripts { pkgs = super; };
  nix-direnv = self.unstable.nix-direnv;

  flameshot = super.flameshot.override {
    enableWlrSupport = true;
    grim = grimFocusedOutput;
  };

} // (if super ? obsidian then {
  # Only apply the Obsidian wrapper if obsidian package exists
  obsidian = super.obsidian.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/obsidian --add-flags "--enable-unsafe-webgpu --lang=en-gb"
    '';
  });
} else
  { })
