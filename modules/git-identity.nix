# Single source of truth for the git author identity — imported by the
# home-manager git config (modules/home-manager/git.nix) and by hosts without
# home-manager that set a system-level git config (hosts/yggdrasil.nix), so
# the two can't drift. Keys match git's `user` section.
{
  name = "Mrinal Purohit";
  email = "github@mrinalpurohit.in";
}
