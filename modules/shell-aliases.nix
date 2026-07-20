# Shell aliases shared between the home-manager zsh module (desktops) and the
# NixOS server profile (modules/nixos/server-profile.nix), so muscle memory
# stays identical across every machine. Plain data, no module arguments —
# imported wherever a `shellAliases` attrset is wanted. Desktop- or GUI-only
# aliases (e.g. autorandr) are added by the consumer, not kept here.
#
# `tmuxdir` calls the `new-tmux-from-dir-name` shell function; both the desktop
# zsh module and the server profile define it, so the alias resolves on both.
{
  cal = "cal -w"; # show week numbers (Monday-start comes from en_GB locale)
  tmuxnew = "tmux -u attach -t play || tmux -u new -s play";
  tmuxdir = "new-tmux-from-dir-name";
  proc = "ps aux | rg";
}
