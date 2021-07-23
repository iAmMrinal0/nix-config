{ lib, wallpaper }:

{
  enable = true;
  hooks = { postswitch = { "change-background" = wallpaper; }; };
}
