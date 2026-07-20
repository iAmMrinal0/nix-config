# Atuin UX settings shared between the home-manager module (desktops) and the
# NixOS server profile, so history search behaves identically everywhere.
# Plain data — the sync/key settings differ per machine and are layered on by
# each consumer (desktops sync via a sops-provided key; servers run unsynced),
# so only the machine-independent behaviour lives here.
{
  enter_accept = true;
  # No filter_mode set: the default is the first applicable entry below, so
  # inside a git repo it's "workspace" (whole-repo history, needs workspaces =
  # true) and "host" elsewhere.
  search.filters = [
    "workspace"
    "host"
    "session"
    "directory"
    "global"
  ];
  filter_mode_shell_up_key_binding = "directory";
  show_preview = true;
  # Filter history to the whole git repo, not just the exact cwd, when using
  # the directory/workspace filter.
  workspaces = true;
  # Open interactive search in a tmux popup (tmux >= 3.2).
  tmux.enabled = true;
}
