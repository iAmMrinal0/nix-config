{ pkgs, ... }:

{
  # `programs.adb` was removed in 26.05: systemd 258 installs the uaccess
  # udev rules for Android devices automatically, so the option no longer
  # does anything. All that's left to provide is the `adb` command itself.
  environment.systemPackages = [ pkgs.android-tools ];
}
