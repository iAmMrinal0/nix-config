{ writeShellScriptBin, cryptomator, coreutils }:

# Launch Cryptomator, first clearing any orphaned FUSE mounts left behind by a
# session that died without unmounting (sway crash, OOM, kill -9).
#
# When the compositor goes down it takes the Cryptomator JVM with it, but the
# kernel mount at ~/.local/share/Cryptomator/mnt/<vault> outlives the daemon that
# backed it: the entry stats as d????????? and `ls` reports "Transport endpoint is
# not connected". On the next unlock, Mounter$SettledMounter.prepareMountPoint
# calls Files.createDirectories, the kernel answers EEXIST for the dead
# mountpoint, and the unlock dies with FileAlreadyExistsException (Cryptomator
# error code N05M:RI0E:RI0E). Cryptomator never sweeps these itself, so the vault
# stays unusable until you unmount by hand.
#
# ENOTCONN is what makes the sweep safe, and it's why we match on the stat error
# rather than just "stat failed": a *live* mount stats fine, a plain idle
# mountpoint dir stats fine, and a path that isn't there gives ENOENT. Only a
# mount whose FUSE daemon is gone reports ENOTCONN, so this cannot tear down a
# vault that's actually in use. LC_ALL=C pins the message so the match doesn't
# depend on locale. Mountpoint dirs are left in place — that's their normal state
# between unlocks.
#
# fusermount3 must be the /run/wrappers setuid copy, same as the rclone unmounts
# in modules/home-manager/systemd.nix: the nixpkgs store binary isn't setuid and
# can't unmount unprivileged, and `${fuse3}/bin` doesn't even exist (the helper
# lives in fuse3's separate `bin` output).
writeShellScriptBin "cryptomator-launch" ''
  mnt="''${XDG_DATA_HOME:-$HOME/.local/share}/Cryptomator/mnt"

  for target in "$mnt"/*; do
    err=$(LC_ALL=C ${coreutils}/bin/stat "$target" 2>&1 >/dev/null) || true
    case "$err" in
    *"Transport endpoint is not connected"*)
      echo "cryptomator-launch: clearing stale mount $target"
      # Lazy detach as the fallback: the backing daemon is already gone, so
      # there is nothing left to flush. Never fail the launch over a sweep.
      /run/wrappers/bin/fusermount3 -u "$target" \
        || /run/wrappers/bin/fusermount3 -uz "$target" \
        || true
      ;;
    esac
  done

  exec ${cryptomator}/bin/cryptomator "$@"
''
