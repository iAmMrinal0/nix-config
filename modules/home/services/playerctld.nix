{ config, pkgs, lib, ... }:

{
  options = { };

  config = { services.playerctld.enable = true; };
}
