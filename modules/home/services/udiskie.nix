{ config, pkgs, lib, ... }:

{
  options = { };

  config = { services.udiskie.enable = true; };
}
